import AppKit
import Observation

/// Central mutation point for everything Pawprint records. Tracking services never touch
/// storage directly — they call into `ActivityCenter`, which applies the pause/excluded-app
/// gate, updates the in-memory `today` counters, and periodically flushes to disk.
/// This keeps every privacy rule ("don't record while paused", "don't record excluded apps")
/// enforced in exactly one place.
@Observable
final class ActivityCenter {
    static let shared = ActivityCenter()

    private(set) var settings: AppSettings
    private(set) var currentFrontmostBundleID: String?
    private(set) var currentFrontmostAppName: String?

    /// Raw counters for the current day.
    ///
    /// Deliberately NOT `@Observable`-tracked: it mutates on every keystroke and mouse delta
    /// (tens of times per second), and any view that read it directly would be invalidated at
    /// that rate — which is what made tab switching feel sluggish. Views read `todaySummary`
    /// instead, which is a snapshot refreshed on a timer.
    @ObservationIgnored private(set) var today: DailyRawCounters

    /// Display-ready snapshot of today, recomputed at most every `summaryRefreshInterval`.
    /// This is the *only* today-derived value views should observe.
    private(set) var todaySummary: DailySummary

    /// Live typing speed, refreshed on the same cadence as `todaySummary` so the mascot and
    /// menu bar can react without re-rendering on every keypress.
    private(set) var liveWPM: Double = 0

    /// The stretch of work happening right now, reset whenever an idle gap breaks it. Powers the
    /// live HUD, where the appeal is watching these climb in real time.
    private(set) var sessionStart: Date?
    private(set) var sessionKeyPresses: Int = 0
    private(set) var sessionClicks: Int = 0

    var sessionSeconds: Int {
        guard let sessionStart else { return 0 }
        return max(0, Int(Date().timeIntervalSince(sessionStart)))
    }

    /// Personal bests over days before today, and how today stands against them.
    private(set) var personalBests: [PersonalBest] = []

    /// Where today ranks among every recorded day. Pre-sorted samples are rebuilt with the
    /// lifetime stats; the per-refresh cost is only a binary search per metric.
    private(set) var todayPercentiles: [PercentileRanking] = []
    @ObservationIgnored private var percentileSamples: [String: [Double]] = [:]

    /// The single "how busy was today" ranking, preferring the composite score.
    var headlinePercentile: PercentileRanking? {
        todayPercentiles.first { $0.metricID == PercentileEngine.scoreKey } ?? todayPercentiles.first
    }

    /// True when recording is actually happening right now (not paused, current app not excluded).
    var isRecordingActive: Bool {
        !settings.isPaused && !isCurrentAppExcluded
    }

    private(set) var isCurrentAppExcluded: Bool = false

    @ObservationIgnored private var currentDayString: String
    @ObservationIgnored private let store = PawprintStore.shared
    @ObservationIgnored private var flushTimer: Timer?
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var summaryTimer: Timer?

    static let summaryRefreshInterval: TimeInterval = 1.5

    @ObservationIgnored let focusEngine = FocusEngine()

    // Rolling window of character-key timestamps, used to compute live WPM.
    @ObservationIgnored private var recentCharKeyTimes: [Date] = []
    @ObservationIgnored private var typingStreakStart: Date?
    @ObservationIgnored private var lastCharKeyTime: Date?
    @ObservationIgnored private var lastActivityTime: Date?
    @ObservationIgnored private var activitySessionStart: Date?
    @ObservationIgnored private var recentDaysCache: [DailyRawCounters] = []

    static let idleGapSeconds: TimeInterval = 90
    static let typingStreakGapSeconds: TimeInterval = 3

    private init() {
        var loadedSettings = PawprintStore.shared.loadSettings()
        // Applied here rather than in the decoder so the result is actually persisted; a decoder
        // fix-up lives only in memory until something unrelated happens to save.
        if let migrated = loadedSettings.migratedForUpdateDefaults() {
            loadedSettings = migrated
            PawprintStore.shared.saveSettings(migrated)
        }
        LocalizationManager.shared.apply(loadedSettings.language)
        self.settings = loadedSettings
        let day = DayKey.today(dayStartHour: loadedSettings.dayStartHour)
        self.currentDayString = day
        let loadedToday = PawprintStore.shared.loadDay(day) ?? DailyRawCounters(day: day)
        self.today = loadedToday
        self.todaySummary = StatsEngine.summary(for: loadedToday, dayStartHour: loadedSettings.dayStartHour)
        focusEngine.focusThresholdSeconds = TimeInterval(loadedSettings.focusThresholdSeconds)
        reloadRecentDaysCache()
        // Percentile ranking and personal bests both need the full history, so prime them at
        // launch instead of waiting for the Records tab to be opened.
        refreshLifetimeStats(force: true)
    }

    func start() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.persist()
        }
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.tick()
        }
        summaryTimer?.invalidate()
        let timer = Timer(timeInterval: Self.summaryRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshSummary()
        }
        RunLoop.main.add(timer, forMode: .common)
        summaryTimer = timer
    }

    func stop() {
        flushTimer?.invalidate()
        tickTimer?.invalidate()
        summaryTimer?.invalidate()
        persist()
    }

    /// Recomputes the observable today-snapshot. Skips the work entirely when nothing has been
    /// recorded since the last refresh, so an idle Mac costs nothing.
    private func refreshSummary() {
        let now = Date()
        let newLiveWPM = Double(recentCharKeyTimes.filter { now.timeIntervalSince($0) <= 60 }.count) / 5.0
        if newLiveWPM != liveWPM {
            liveWPM = newLiveWPM
        }
        guard dirtySinceLastSummary else { return }
        dirtySinceLastSummary = false
        todaySummary = StatsEngine.summary(for: today, recentDays: recentDaysCache, dayStartHour: settings.dayStartHour)
        if currentStreak == 0 { recomputeStreak() }
        AchievementEngine.shared.evaluate(summary: todaySummary, currentStreak: currentStreak)
        if let celebrated = RecordTracker.shared.evaluate(
            today: todaySummary,
            bests: personalBests,
            alreadyCelebrated: Set(settings.celebratedRecords)
        ) {
            var updated = settings
            updated.celebratedRecords = Array(celebrated).sorted()
            updateSettings(updated)
        }
        todayPercentiles = PercentileEngine.rankings(for: todaySummary, samples: percentileSamples)
    }

    @ObservationIgnored private var dirtySinceLastSummary = false

    /// Snapshot of the previous 7 days, used for the "vs. recent average" sentence. Reloaded
    /// only on launch and day rollover — not per event.
    private func reloadRecentDaysCache() {
        let start = DayKey.addingDays(-7, to: currentDayString)
        recentDaysCache = store.loadDays(from: start, to: currentDayString).filter { $0.day != currentDayString }
        recentSummaries = recentDaysCache.map {
            SummaryCache.shared.summary(for: $0, dayStartHour: settings.dayStartHour)
        }
        recomputeStreak()
    }

    /// Derived summaries for the previous 7 days, powering the "오늘 vs 평소" comparison without
    /// each view having to hit the database.
    private(set) var recentSummaries: [DailySummary] = []

    /// Consecutive days (ending today) with any recorded activity. Computed from the recent-days
    /// cache plus today, so it costs nothing per event.
    private(set) var currentStreak: Int = 0

    /// All-time totals and the level progression built from them. Rebuilt on demand (launch,
    /// day rollover, or when a view explicitly asks) rather than per event — it reads every
    /// stored day, so it must never sit on a hot path.
    private(set) var lifetimeStats = LifetimeStats()
    private(set) var quests: [QuestProgress] = []
    private(set) var overallLevel = OverallLevel(level: 1, title: L10n.t("activityCenter.e10505c5"), totalLevels: 0)

    @ObservationIgnored private var lastLifetimeRefresh: Date?

    /// Recomputes lifetime totals. Throttled so repeated tab visits don't rescan the database.
    func refreshLifetimeStats(force: Bool = false) {
        if !force, let last = lastLifetimeRefresh, Date().timeIntervalSince(last) < 60 { return }
        lastLifetimeRefresh = Date()

        let todayKey = currentDayString
        var summaries = store.allDays()
            .filter { $0.day != todayKey }
            .map { SummaryCache.shared.summary(for: $0, dayStartHour: settings.dayStartHour) }
        summaries.append(todaySummary)
        summaries.sort { $0.day < $1.day }

        // Bests must come from days *before* today, otherwise today can never beat its own entry.
        let pastDays = summaries.filter { $0.day != todayKey }
        personalBests = RecordTracker.personalBests(fromPastDays: pastDays)
        percentileSamples = PercentileEngine.buildSamples(fromPastDays: pastDays)
        lifetimeStats = LifetimeStats.build(from: summaries)
        let newQuests = QuestTrack.allCases.map { QuestProgress.build(track: $0, stats: lifetimeStats) }
        announceLevelUps(from: quests, to: newQuests)
        quests = newQuests
        overallLevel = OverallLevel.build(from: newQuests)
    }

    /// Level-ups are the one thing worth interrupting the user for — they happen a handful of
    /// times a week, not continuously like records do.
    ///
    /// Two guards, because the in-memory comparison alone was not enough. `notifiedQuestLevels`
    /// is persisted, so relaunching can't re-announce a level already seen; the daily count caps
    /// how many can arrive even on a day that crosses several tracks at once.
    private func announceLevelUps(from previous: [QuestProgress], to updated: [QuestProgress]) {
        guard !previous.isEmpty else {
            // First refresh after launch: record where every track already stands without
            // announcing anything, so a fresh install doesn't fire one alert per track.
            seedNotifiedLevels(updated)
            return
        }

        var levelled: [QuestProgress] = []
        for new in updated {
            guard let old = previous.first(where: { $0.track == new.track }), new.level > old.level else { continue }
            levelled.append(new)
        }
        guard !levelled.isEmpty else { return }

        // The overlay shows the biggest jump; the notification budget is spent on the same ones.
        pendingLevelUp = levelled.max(by: { $0.level < $1.level })

        var updatedSettings = settings
        let day = currentDayString
        if updatedSettings.notificationDay != day {
            updatedSettings.notificationDay = day
            updatedSettings.notificationCountToday = 0
        }

        var changed = updatedSettings.notificationDay != settings.notificationDay
            || updatedSettings.notificationCountToday != settings.notificationCountToday

        for quest in levelled.sorted(by: { $0.level > $1.level }) {
            let key = quest.track.rawValue
            let alreadyNotified = updatedSettings.notifiedQuestLevels[key] ?? -1
            guard quest.level > alreadyNotified else { continue }
            updatedSettings.notifiedQuestLevels[key] = quest.level
            changed = true

            guard settings.celebrationNotificationsEnabled,
                  updatedSettings.notificationCountToday < AppSettings.maxAchievementNotificationsPerDay
            else { continue }
            updatedSettings.notificationCountToday += 1

            let title = L10n.t("activityCenter.44529013", quest.track.emoji)
            let body = L10n.t("activityCenter.96eadd51", quest.displayTitle, quest.level)
            Task { @MainActor in
                await NotificationManager.shared.announce(title: title, body: body)
            }
        }

        if changed { updateSettings(updatedSettings) }
    }

    private func seedNotifiedLevels(_ quests: [QuestProgress]) {
        var updated = settings
        var changed = false
        for quest in quests where (updated.notifiedQuestLevels[quest.track.rawValue] ?? -1) < quest.level {
            updated.notifiedQuestLevels[quest.track.rawValue] = quest.level
            changed = true
        }
        if changed { updateSettings(updated) }
    }

    /// Set when a quest track levels up, so the UI can celebrate. Cleared by the view.
    var pendingLevelUp: QuestProgress?

    func clearLevelUp() { pendingLevelUp = nil }

    private func recomputeStreak() {
        var activeDays = Set(recentDaysCache.filter { $0.activeSeconds > 0 }.map { $0.day })
        if today.activeSeconds > 0 || today.totalKeyPresses > 0 {
            activeDays.insert(currentDayString)
        }
        var streak = 0
        var cursor = currentDayString
        while activeDays.contains(cursor) {
            streak += 1
            cursor = DayKey.addingDays(-1, to: cursor)
        }
        currentStreak = streak
    }

    // MARK: - Settings

    func updateSettings(_ newSettings: AppSettings) {
        let dockIconChanged = newSettings.showDockIcon != settings.showDockIcon
        let dayStartChanged = newSettings.dayStartHour != settings.dayStartHour
        let focusThresholdChanged = newSettings.focusThresholdSeconds != settings.focusThresholdSeconds
        LocalizationManager.shared.apply(newSettings.language)
        settings = newSettings
        store.saveSettings(newSettings)
        refreshExclusionState()
        if dockIconChanged {
            NSApp.setActivationPolicy(newSettings.showDockIcon ? .regular : .accessory)
        }
        if focusThresholdChanged {
            focusEngine.focusThresholdSeconds = TimeInterval(newSettings.focusThresholdSeconds)
        }
        if dayStartChanged {
            SummaryCache.shared.invalidateAll()
            reloadRecentDaysCache()
        }
        dirtySinceLastSummary = true
        refreshSummary()
    }

    private func refreshExclusionState() {
        isCurrentAppExcluded = currentFrontmostBundleID.map { bundleID in
            settings.excludedApps.contains { $0.bundleID == bundleID }
        } ?? false
    }

    // MARK: - Day rollover & persistence

    private func rolloverIfNeeded(at date: Date) {
        let dayNow = DayKey.string(for: date, dayStartHour: settings.dayStartHour)
        guard dayNow != currentDayString else { return }
        persist()
        let finishedDay = currentDayString
        currentDayString = dayNow
        today = store.loadDay(dayNow) ?? DailyRawCounters(day: dayNow)
        recentCharKeyTimes.removeAll()
        typingStreakStart = nil
        lastCharKeyTime = nil
        activitySessionStart = nil
        focusEngine.reset()
        SummaryCache.shared.invalidate(finishedDay)
        reloadRecentDaysCache()
        todaySummary = StatsEngine.summary(for: today, recentDays: recentDaysCache, dayStartHour: settings.dayStartHour)
        applyRetentionIfNeeded()
    }

    private func applyRetentionIfNeeded() {
        guard settings.retentionDays > 0 else { return }
        let cutoff = DayKey.addingDays(-settings.retentionDays, to: currentDayString)
        store.deleteDays(before: cutoff)
    }

    func persist() {
        store.saveDay(today)
    }

    /// Re-reads today's counters from disk. Used after Settings deletes today's row (or
    /// everything) so the in-memory snapshot doesn't resurrect what was just deleted on the
    /// next periodic flush.
    func reloadToday() {
        today = store.loadDay(currentDayString) ?? DailyRawCounters(day: currentDayString)
        SummaryCache.shared.invalidateAll()
        reloadRecentDaysCache()
        todaySummary = StatsEngine.summary(for: today, recentDays: recentDaysCache, dayStartHour: settings.dayStartHour)
    }

    private func tick() {
        let now = Date()
        rolloverIfNeeded(at: now)
        closeActivitySessionIfIdle(at: now)
        updateFocusEngine(at: now)
        persist()
    }

    /// Feeds the focus engine the current frontmost app and last input time. Must run on a timer,
    /// not only on app switches — uninterrupted work in one app produces no switch events, and
    /// that's exactly the case focus tracking exists to catch.
    private func updateFocusEngine(at now: Date) {
        guard !settings.isPaused, settings.collectAppUsage else { return }
        focusEngine.update(
            now: now,
            frontmostBundleID: isCurrentAppExcluded ? nil : currentFrontmostBundleID,
            frontmostAppName: isCurrentAppExcluded ? nil : currentFrontmostAppName,
            lastActivityAt: today.lastActivity,
            emit: { [weak self] session, interruptions in
                guard let self else { return }
                self.today.focusSessions.append(session)
                for (app, count) in interruptions {
                    self.today.focusInterruptionsByApp[app, default: 0] += count
                }
                self.dirtySinceLastSummary = true
            }
        )
    }

    // MARK: - Shared bookkeeping used by every tracker

    func isCategoryEnabled(_ category: CollectionCategory) -> Bool {
        switch category {
        case .keyboard: return settings.collectKeyboard
        case .mouse: return settings.collectMouse
        case .appUsage: return settings.collectAppUsage
        case .clipboard: return settings.collectClipboard
        case .sleepWake: return settings.collectSleepWake
        case .powerPeripherals: return settings.collectPowerPeripherals
        }
    }

    /// Call at the top of every raw event handler. Applies day rollover, the pause/exclusion/
    /// category-toggle gate, and active/idle session bookkeeping. Returns false if the event
    /// should be dropped — a disabled category is treated the same as "never happened", it
    /// doesn't even count toward generic active/idle time.
    @discardableResult
    func beginEvent(at date: Date, category: CollectionCategory) -> Bool {
        rolloverIfNeeded(at: date)
        guard isRecordingActive, isCategoryEnabled(category) else { return false }
        markActivity(at: date)
        dirtySinceLastSummary = true
        return true
    }

    private func markActivity(at date: Date) {
        if today.firstActivity == nil { today.firstActivity = date }
        today.lastActivity = date

        if let lastActivityTime, date.timeIntervalSince(lastActivityTime) > Self.idleGapSeconds {
            closeActivitySession(endingAt: lastActivityTime)
            activitySessionStart = date
            beginLiveSession(at: date)
        } else if activitySessionStart == nil {
            activitySessionStart = date
            beginLiveSession(at: date)
        }
        lastActivityTime = date
    }

    private func beginLiveSession(at date: Date) {
        sessionStart = date
        sessionKeyPresses = 0
        sessionClicks = 0
    }

    private func closeActivitySessionIfIdle(at date: Date) {
        if let lastActivityTime, date.timeIntervalSince(lastActivityTime) > Self.idleGapSeconds {
            closeActivitySession(endingAt: lastActivityTime)
        }
    }

    private func closeActivitySession(endingAt end: Date) {
        guard let start = activitySessionStart else { return }
        if end.timeIntervalSince(start) >= 1 {
            today.activitySessions.append(ActivitySessionRecord(start: start, end: end))
            today.activeSeconds += Int(end.timeIntervalSince(start))
        }
        activitySessionStart = nil
    }

    private func minuteOfDay(_ date: Date) -> Int {
        DayKey.minuteOfDay(for: date, dayStartHour: settings.dayStartHour)
    }

    /// Attributes an input event to the app that was frontmost when it happened. `beginEvent`
    /// has already rejected excluded apps and paused states, so anything reaching here is
    /// attributable. Only the running count changes — nothing about the event itself is stored.
    private func attributeToFrontmostApp(_ apply: (String) -> Void) {
        guard let bundleID = currentFrontmostBundleID, !isExcluded(bundleID: bundleID) else { return }
        apply(bundleID)
        if today.appNames[bundleID] == nil, let name = currentFrontmostAppName {
            today.appNames[bundleID] = name
        }
    }

    // MARK: - Keyboard

    func recordKeyPress(category: KeyCategory, keyCode: UInt16, at date: Date) {
        guard beginEvent(at: date, category: .keyboard) else { return }
        today.totalKeyPresses += 1
        sessionKeyPresses += 1
        today.keyCategoryCounts[category.rawValue, default: 0] += 1
        // Frequency only — no ordering, no produced character. Drives the heatmap.
        today.keyCodeCounts[String(keyCode), default: 0] += 1
        attributeToFrontmostApp { today.appKeyPresses[$0, default: 0] += 1 }
        let minute = minuteOfDay(date)
        today.activityPerMinute[minute] += 1

        if category == .character {
            today.characterKeyPresses += 1
            today.charKeysPerMinute[minute] += 1
            updateTypingStreak(at: date)
            updateLiveWPM(at: date, minute: minute)
        }
    }

    func recordShortcut(_ type: ShortcutType, at date: Date) {
        guard beginEvent(at: date, category: .keyboard) else { return }
        today.shortcutCounts[type.rawValue, default: 0] += 1
    }

    private func updateTypingStreak(at date: Date) {
        if let last = lastCharKeyTime, date.timeIntervalSince(last) <= Self.typingStreakGapSeconds {
            if let start = typingStreakStart {
                let duration = Int(date.timeIntervalSince(start))
                if duration > today.longestTypingStreakSeconds {
                    today.longestTypingStreakSeconds = duration
                }
            }
        } else {
            typingStreakStart = date
            today.typingSessionCount += 1
        }
        lastCharKeyTime = date
    }

    private func updateLiveWPM(at date: Date, minute: Int) {
        recentCharKeyTimes.append(date)
        recentCharKeyTimes.removeAll { date.timeIntervalSince($0) > 60 }
        let wpm = Double(recentCharKeyTimes.count) / 5.0
        if wpm > today.maxWPM && recentCharKeyTimes.count >= 5 {
            today.maxWPM = wpm
            today.maxWPMMinute = minute
        }
    }

    // MARK: - Mouse

    func recordClick(kind: ClickKind, at date: Date) {
        guard beginEvent(at: date, category: .mouse) else { return }
        switch kind {
        case .left: today.leftClicks += 1
        case .right: today.rightClicks += 1
        case .double: today.doubleClicks += 1
        case .drag: today.dragCount += 1
        }
        if kind != .drag { sessionClicks += 1 }
        let minute = minuteOfDay(date)
        today.clicksPerMinute[minute] += 1
        today.activityPerMinute[minute] += 1
        attributeToFrontmostApp { today.appClicks[$0, default: 0] += 1 }
    }

    func recordCursorMovement(distancePixels: Double, speedPxPerSec: Double, at date: Date) {
        guard beginEvent(at: date, category: .mouse) else { return }
        today.cursorDistancePixels += distancePixels
        if speedPxPerSec > today.maxCursorSpeedPxPerSec {
            today.maxCursorSpeedPxPerSec = speedPxPerSec
        }
    }

    func recordScroll(deltaY: Double, deltaX: Double, speedPointsPerSec: Double, at date: Date) {
        guard beginEvent(at: date, category: .mouse) else { return }
        if deltaY > 0 { today.scrollUpPoints += deltaY }
        if deltaY < 0 { today.scrollDownPoints += -deltaY }
        if deltaX != 0 { today.scrollHorizontalPoints += abs(deltaX) }
        if speedPointsPerSec > today.maxScrollSpeedPointsPerSec {
            today.maxScrollSpeedPointsPerSec = speedPointsPerSec
        }
        let minute = minuteOfDay(date)
        let magnitude = abs(deltaY) + abs(deltaX)
        today.scrollPerMinute[minute] += magnitude
        today.activityPerMinute[minute] += 1
        attributeToFrontmostApp { today.appScrollPoints[$0, default: 0] += magnitude }
    }

    func recordScrollDirectionChange(at date: Date) {
        guard beginEvent(at: date, category: .mouse) else { return }
        today.scrollDirectionChanges += 1
    }

    // MARK: - Clipboard

    func recordClipboard(action: ClipboardAction, type: ClipboardDataType, at date: Date) {
        guard beginEvent(at: date, category: .clipboard) else { return }
        switch action {
        case .copy: today.clipboardCopyCount += 1
        case .paste: today.clipboardPasteCount += 1
        case .cut: today.clipboardCutCount += 1
        }
        today.clipboardTypeCounts[type.rawValue, default: 0] += 1
    }

    // MARK: - App usage

    /// System UI processes that become "frontmost" without the user choosing them — the lock
    /// screen, Spotlight, the screensaver. Counting these as apps made the lock screen show up
    /// as the most-used "app" of the day.
    private static let systemProcessBundleIDs: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.ScreenSaver.Engine",
        "com.apple.Spotlight",
        "com.apple.WindowManager",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.CoreServices.uiagent",
    ]

    func isExcluded(bundleID: String) -> Bool {
        Self.systemProcessBundleIDs.contains(bundleID) || settings.excludedApps.contains { $0.bundleID == bundleID }
    }

    /// Records a just-ended app activation period. Gated on that session's *own* app being
    /// excluded — by the time a session ends, `currentFrontmostBundleID` has usually already
    /// moved on to the next app, so the shared `beginEvent` gate would check the wrong app.
    func recordAppSession(_ session: AppSessionRecord) {
        guard !settings.isPaused, settings.collectAppUsage, !isExcluded(bundleID: session.bundleID) else { return }
        rolloverIfNeeded(at: session.end)
        today.appSessions.append(session)
        if session.duration < 5 {
            today.shortDwellCount += 1
        }
        dirtySinceLastSummary = true
    }

    /// Called whenever a new app becomes frontmost. Updates the (always-on) frontmost/exclusion
    /// bookkeeping first, then — gated on the *new* app not being excluded — counts the switch
    /// and feeds the focus-session engine.
    func appDidActivate(bundleID: String, name: String, at date: Date) {
        rolloverIfNeeded(at: date)
        let hadPreviousApp = currentFrontmostBundleID != nil
        currentFrontmostBundleID = bundleID
        currentFrontmostAppName = name
        refreshExclusionState()

        guard beginEvent(at: date, category: .appUsage) else { return }
        if hadPreviousApp {
            today.totalAppSwitches += 1
        }
        focusEngine.appActivated(
            bundleID: bundleID,
            name: name,
            at: date,
            lastActivityAt: today.lastActivity
        ) { [weak self] session, interruptions in
            guard let self else { return }
            self.today.focusSessions.append(session)
            for (app, count) in interruptions {
                self.today.focusInterruptionsByApp[app, default: 0] += count
            }
        }
    }

    func recordAppLaunch(bundleID: String, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectAppUsage, !isExcluded(bundleID: bundleID) else { return }
        rolloverIfNeeded(at: date)
        today.appLaunchCounts[bundleID, default: 0] += 1
    }

    func recordAppTerminate(bundleID: String, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectAppUsage, !isExcluded(bundleID: bundleID) else { return }
        rolloverIfNeeded(at: date)
        today.appTerminateCounts[bundleID, default: 0] += 1
    }

    // MARK: - Mac state

    func recordMacState(_ event: SleepWakeRecord) {
        rolloverIfNeeded(at: event.timestamp)
        switch event.type {
        case .sleep, .wake, .screenLock, .screenUnlock:
            guard !settings.isPaused, settings.collectSleepWake else { return }
        case .chargerConnect, .chargerDisconnect:
            guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        }
        today.sleepWakeEvents.append(event)
        switch event.type {
        case .sleep, .wake: break
        case .screenLock: today.lockCount += 1
        case .screenUnlock: today.unlockCount += 1
        case .chargerConnect: today.chargerConnectCount += 1
        case .chargerDisconnect: today.chargerDisconnectCount += 1
        }
        dirtySinceLastSummary = true
    }

    func recordBatterySample(_ sample: BatterySample) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: sample.timestamp)
        today.batterySamples.append(sample)
        if today.batterySamples.count > 500 {
            today.batterySamples.removeFirst(today.batterySamples.count - 500)
        }
        dirtySinceLastSummary = true
    }

    // MARK: - Power detail

    /// Accumulates elapsed time in each power/thermal state. Called on a slow timer with the
    /// interval since the previous call, so the totals stay right even across missed ticks.
    func accumulatePowerTime(
        seconds: Int,
        onAC: Bool,
        lowPowerMode: Bool,
        elevatedThermal: Bool,
        at date: Date = Date()
    ) {
        guard seconds > 0, !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        if onAC {
            today.secondsOnAC += seconds
        } else {
            today.secondsOnBattery += seconds
        }
        if lowPowerMode { today.lowPowerModeSeconds += seconds }
        if elevatedThermal { today.elevatedThermalSeconds += seconds }
        dirtySinceLastSummary = true
    }

    func beginChargeSession(startLevel: Int, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        today.chargeSessions.append(ChargeSessionRecord(start: date, startLevel: startLevel))
        dirtySinceLastSummary = true
    }

    func endChargeSession(endLevel: Int, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        guard let index = today.chargeSessions.lastIndex(where: { $0.end == nil }) else { return }
        today.chargeSessions[index].end = date
        today.chargeSessions[index].endLevel = endLevel
        dirtySinceLastSummary = true
    }

    // MARK: - Lid (clamshell)

    func recordLidChange(closed: Bool, closedForSeconds: Int = 0, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        if closed {
            today.lidCloseCount += 1
        } else {
            today.lidOpenCount += 1
            today.lidClosedSeconds += max(0, closedForSeconds)
        }
        dirtySinceLastSummary = true
    }

    // MARK: - Displays & audio

    func recordDisplayChange(connected: Int, disconnected: Int, totalDisplays: Int, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        today.externalDisplayConnectCount += connected
        today.externalDisplayDisconnectCount += disconnected
        today.maxSimultaneousDisplays = max(today.maxSimultaneousDisplays, totalDisplays)
        dirtySinceLastSummary = true
    }

    func recordAudioOutputChange(at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        today.audioOutputDeviceChangeCount += 1
        dirtySinceLastSummary = true
    }

    func recordDisplaySleep(at date: Date = Date()) {
        guard !settings.isPaused, settings.collectSleepWake else { return }
        rolloverIfNeeded(at: date)
        today.displaySleepCount += 1
        dirtySinceLastSummary = true
    }

    func recordDisplayWake(at date: Date = Date()) {
        guard !settings.isPaused, settings.collectSleepWake else { return }
        rolloverIfNeeded(at: date)
        today.displayWakeCount += 1
        dirtySinceLastSummary = true
    }

    /// Adds elapsed wall-clock seconds during which the display was lit. Accumulated by the
    /// same slow sampler that tracks power state, so a missed tick can't inflate the total.
    func accumulateScreenOnTime(seconds: Int, at date: Date = Date()) {
        guard seconds > 0, !settings.isPaused else { return }
        rolloverIfNeeded(at: date)
        today.screenOnSeconds += seconds
        dirtySinceLastSummary = true
    }

    /// Records a network-usage delta measured over `overSeconds`. Gated on the same
    /// power/peripherals category as other passive system metrics.
    func recordNetworkTraffic(downloadBytes: UInt64, uploadBytes: UInt64, overSeconds: TimeInterval, at date: Date = Date()) {
        guard !settings.isPaused, settings.collectPowerPeripherals else { return }
        rolloverIfNeeded(at: date)
        today.networkDownloadBytes += downloadBytes
        today.networkUploadBytes += uploadBytes
        if overSeconds > 0 {
            let downRate = Double(downloadBytes) / overSeconds
            let upRate = Double(uploadBytes) / overSeconds
            if downRate > today.peakDownloadBytesPerSec { today.peakDownloadBytesPerSec = downRate }
            if upRate > today.peakUploadBytesPerSec { today.peakUploadBytesPerSec = upRate }
        }
        dirtySinceLastSummary = true
    }

    func recordDragDistance(points: Double, at date: Date) {
        guard beginEvent(at: date, category: .mouse) else { return }
        today.dragDistancePoints += points
    }
}

enum ClickKind {
    case left, right, double, drag
}

enum CollectionCategory {
    case keyboard, mouse, appUsage, clipboard, sleepWake, powerPeripherals
}
