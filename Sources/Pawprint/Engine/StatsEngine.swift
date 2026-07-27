import Foundation

/// Turns raw counters into everything the UI shows: real numbers (WPM, focus time, app usage)
/// and the lighthearted derived stuff (regret/chaos index, activity tag, approximate
/// conversions). Nothing here is persisted — it's recomputed from `DailyRawCounters` on demand,
/// so display logic can evolve without touching what's stored on disk.
enum StatsEngine {

    /// Conversion constants for "재미있는 환산 표현". Physical display geometry is *not* here —
    /// that comes from `DisplayMetrics`, measured from the actual panel.
    enum FunFactConstants {
        static let trackLoopMeters = 400.0
        static let buildingFloorMeters = 3.2
        static let a4CharsPerPage = 1800.0
        static let averageMovieMinutes = 110.0
    }

    static func summary(
        for raw: DailyRawCounters,
        recentDays: [DailyRawCounters] = [],
        dayStartHour: Int = 0
    ) -> DailySummary {
        var s = DailySummary(day: raw.day)

        // MARK: Keyboard
        s.totalKeyPresses = raw.totalKeyPresses
        s.characterKeyPresses = raw.characterKeyPresses
        s.maxWPM = raw.maxWPM
        s.longestTypingStreakSeconds = raw.longestTypingStreakSeconds
        s.typingSessionCount = raw.typingSessionCount
        if let minute = raw.maxWPMMinute {
            s.maxWPMTime = date(forMinute: minute, day: raw.day, dayStartHour: dayStartHour)
        }
        s.keyCategoryCounts = Dictionary(uniqueKeysWithValues: raw.keyCategoryCounts.compactMap { key, value in
            KeyCategory(rawValue: key).map { ($0, value) }
        })
        s.shortcutCounts = Dictionary(uniqueKeysWithValues: raw.shortcutCounts.compactMap { key, value in
            ShortcutType(rawValue: key).map { ($0, value) }
        })
        let backspaceCount = s.keyCategoryCounts[.backspace] ?? 0
        s.backspaceRatio = raw.totalKeyPresses > 0 ? Double(backspaceCount) / Double(raw.totalKeyPresses) : 0
        if raw.activeSeconds > 0 {
            s.avgWPM = (Double(raw.characterKeyPresses) / 5.0) / (Double(raw.activeSeconds) / 60.0)
        }

        // MARK: Mouse
        s.leftClicks = raw.leftClicks
        s.rightClicks = raw.rightClicks
        s.doubleClicks = raw.doubleClicks
        s.dragCount = raw.dragCount
        s.totalClicks = raw.leftClicks + raw.rightClicks + raw.doubleClicks
        s.maxClicksPerMinute = raw.clicksPerMinute.max() ?? 0
        s.cursorDistanceMeters = DisplayMetrics.shared.meters(fromPoints: raw.cursorDistancePixels)
        s.maxCursorSpeedPxPerSec = raw.maxCursorSpeedPxPerSec
        s.totalScrollPoints = raw.scrollUpPoints + raw.scrollDownPoints + raw.scrollHorizontalPoints
        s.scrollScreens = DisplayMetrics.shared.screens(fromScrollPoints: s.totalScrollPoints)
        s.scrollUpPoints = raw.scrollUpPoints
        s.scrollDownPoints = raw.scrollDownPoints
        s.scrollDirectionChanges = raw.scrollDirectionChanges

        // MARK: Clipboard
        s.clipboardCopyCount = raw.clipboardCopyCount
        s.clipboardPasteCount = raw.clipboardPasteCount
        s.clipboardCutCount = raw.clipboardCutCount
        s.clipboardTypeCounts = Dictionary(uniqueKeysWithValues: raw.clipboardTypeCounts.compactMap { key, value in
            ClipboardDataType(rawValue: key).map { ($0, value) }
        })

        // MARK: Apps
        let appUsage = aggregateAppUsage(raw.appSessions)
        s.appUsage = appUsage
        s.topApp = appUsage.first
        s.totalAppSwitches = raw.totalAppSwitches
        s.shortDwellCount = raw.shortDwellCount
        if !raw.appSessions.isEmpty {
            s.avgAppDwellSeconds = raw.appSessions.map(\.duration).reduce(0, +) / Double(raw.appSessions.count)
        }

        // MARK: Time / focus
        s.firstActivity = raw.firstActivity
        s.lastActivity = raw.lastActivity
        s.activeSeconds = raw.activeSeconds
        if let first = raw.firstActivity, let last = raw.lastActivity {
            let span = Int(last.timeIntervalSince(first))
            s.idleSeconds = max(0, span - raw.activeSeconds)
        }
        s.activitySessionCount = raw.activitySessions.count
        if !raw.activitySessions.isEmpty {
            s.avgSessionSeconds = raw.activitySessions.map(\.duration).reduce(0, +) / Double(raw.activitySessions.count)
        }
        s.focusSessionCount = raw.focusSessions.count
        s.totalFocusSeconds = Int(raw.focusSessions.map(\.duration).reduce(0, +))
        s.longestFocusSeconds = Int(raw.focusSessions.map(\.duration).max() ?? 0)
        if !raw.focusSessions.isEmpty {
            s.avgFocusSeconds = Double(s.totalFocusSeconds) / Double(raw.focusSessions.count)
        }
        s.bestFocusHour = bestFocusHour(raw.focusSessions)
        s.topInterruptingApp = raw.focusInterruptionsByApp.max { $0.value < $1.value }?.key

        // MARK: Mac state
        s.sleepCount = raw.sleepWakeEvents.filter { $0.type == .sleep }.count
        s.wakeCount = raw.sleepWakeEvents.filter { $0.type == .wake }.count
        let sleepDurations = raw.sleepWakeEvents.filter { $0.type == .wake }.map(\.durationSeconds)
        s.totalSleepSeconds = sleepDurations.reduce(0, +)
        s.longestSleepSeconds = sleepDurations.max() ?? 0
        s.lockCount = raw.lockCount
        s.unlockCount = raw.unlockCount

        // MARK: Power
        s.chargerConnectCount = raw.chargerConnectCount
        s.chargerDisconnectCount = raw.chargerDisconnectCount
        let levels = raw.batterySamples.map(\.level)
        s.minBatteryLevel = levels.min()
        s.maxBatteryLevel = levels.max()
        s.currentBatteryLevel = raw.batterySamples.last?.level
        s.secondsOnBattery = raw.secondsOnBattery
        s.secondsOnAC = raw.secondsOnAC
        s.chargeSessionCount = raw.chargeSessions.count
        s.totalChargedPercent = raw.chargeSessions.compactMap(\.gainedPercent).reduce(0, +)
        s.batteryDrainedPercent = batteryDrained(raw.batterySamples)
        s.lowPowerModeSeconds = raw.lowPowerModeSeconds
        s.elevatedThermalSeconds = raw.elevatedThermalSeconds
        s.batteryTimeline = raw.batterySamples

        // MARK: Lid
        s.lidCloseCount = raw.lidCloseCount
        s.lidOpenCount = raw.lidOpenCount
        s.lidClosedSeconds = raw.lidClosedSeconds

        // MARK: Displays & audio
        s.externalDisplayConnectCount = raw.externalDisplayConnectCount
        s.externalDisplayDisconnectCount = raw.externalDisplayDisconnectCount
        s.maxSimultaneousDisplays = raw.maxSimultaneousDisplays
        s.audioOutputDeviceChangeCount = raw.audioOutputDeviceChangeCount
        s.displaySleepCount = raw.displaySleepCount
        s.displayWakeCount = raw.displayWakeCount

        // MARK: Screen time
        s.screenOnSeconds = raw.screenOnSeconds
        s.screenIdleSeconds = max(0, raw.screenOnSeconds - raw.activeSeconds)
        if raw.screenOnSeconds > 0 {
            s.screenUtilizationPercent = min(100, Int((Double(raw.activeSeconds) / Double(raw.screenOnSeconds) * 100).rounded()))
        }

        // MARK: Extra derived detail
        s.dragDistanceMeters = DisplayMetrics.shared.meters(fromPoints: raw.dragDistancePoints)
        s.typingConsistency = typingConsistency(raw.charKeysPerMinute)
        let golden = goldenHour(raw.charKeysPerMinute, dayStartHour: dayStartHour)
        s.goldenHour = golden?.hour
        s.goldenHourWPM = golden?.wpm ?? 0
        s.distinctShortcutsUsed = raw.shortcutCounts.filter { $0.value > 0 }.count

        // MARK: Keyboard heatmap
        s.keyCodeCounts = Dictionary(
            raw.keyCodeCounts.compactMap { key, value -> (UInt16, Int)? in
                guard let code = UInt16(key) else { return nil }
                return (code, value)
            },
            uniquingKeysWith: +
        )
        s.distinctKeysUsed = s.keyCodeCounts.count
        if let top = s.keyCodeCounts.max(by: { $0.value < $1.value }) {
            s.mostPressedKeyLabel = KeyboardLayout.label(for: top.key)
            s.mostPressedKeyCount = top.value
        }
        let handAndRow = handAndRowShares(s.keyCodeCounts)
        s.leftHandPercent = handAndRow.leftPercent
        s.keyRowShares = handAndRow.rowShares

        // MARK: Network
        s.networkDownloadBytes = raw.networkDownloadBytes
        s.networkUploadBytes = raw.networkUploadBytes
        s.networkTotalBytes = raw.networkDownloadBytes + raw.networkUploadBytes
        s.peakDownloadBytesPerSec = raw.peakDownloadBytesPerSec
        s.peakUploadBytesPerSec = raw.peakUploadBytesPerSec

        // MARK: Per-app input profile
        s.appInputProfiles = appInputProfiles(raw: raw, usage: appUsage)
        s.topTypingApp = s.appInputProfiles.filter { $0.keyPresses > 0 }.max { $0.keyPresses < $1.keyPresses }
        s.topClickingApp = s.appInputProfiles.filter { $0.clicks > 0 }.max { $0.clicks < $1.clicks }

        // MARK: App concentration
        let concentration = appConcentration(s.appUsage)
        s.appConcentration = concentration.percent
        s.appsToReachHalfTime = concentration.appsForHalf
        s.longestBreakSeconds = longestBreak(raw.activitySessions)
        if s.totalClicks > 0 {
            s.doubleClickRatio = Double(raw.doubleClicks) / Double(s.totalClicks)
            s.scrollToClickRatio = s.scrollScreens / Double(s.totalClicks)
        }

        // MARK: Timeline
        s.activityPerMinute = raw.activityPerMinute
        s.charKeysPerMinute = raw.charKeysPerMinute

        // MARK: Derived / fun
        s.regretIndex = regretIndex(raw: raw, backspaceRatio: s.backspaceRatio)
        s.chaosIndex = chaosIndex(raw: raw)
        s.activityTags = activityTags(raw: raw, summary: s)
        s.batteryCycleCount = BatteryHardware.shared.cycleCount
        s.batteryHealthPercent = BatteryHardware.shared.healthPercent
        s.energyFacts = FunConversions.energyFacts(fromBatteryPercent: s.batteryDrainedPercent)
        s.fingerTravelMeters = FunConversions.fingerTravelMeters(keystrokes: s.totalKeyPresses)
        if let peak = raw.activityPerMinute.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
            s.busiestMinute = peak.offset
            s.busiestMinuteCount = peak.element
        }
        s.score = PawprintScore.build(from: s)
        s.persona = DailyPersona.build(from: s)
        s.highlights = highlights(raw: raw, summary: s, dayStartHour: dayStartHour)
        s.funFacts = funFacts(raw: raw, summary: s)
        s.summarySentence = summarySentence(raw: raw, summary: s, recentDays: recentDays)

        return s
    }

    // MARK: - App usage aggregation

    private static func aggregateAppUsage(_ sessions: [AppSessionRecord]) -> [AppUsageStat] {
        var byApp: [String: (name: String, seconds: TimeInterval, count: Int)] = [:]
        for session in sessions {
            var entry = byApp[session.bundleID] ?? (session.appName, 0, 0)
            entry.seconds += session.duration
            entry.count += 1
            byApp[session.bundleID] = entry
        }
        return byApp.map { bundleID, value in
            AppUsageStat(bundleID: bundleID, appName: value.name, totalSeconds: value.seconds, activationCount: value.count)
        }.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// Splits keystrokes by which hand normally presses each key, and by keyboard row.
    /// Keys the layout doesn't know about (external/foreign keyboards) are simply skipped.
    private static func handAndRowShares(_ counts: [UInt16: Int]) -> (leftPercent: Int, rowShares: [KeyboardKey.Row: Int]) {
        var left = 0
        var right = 0
        var byRow: [KeyboardKey.Row: Int] = [:]

        for key in KeyboardLayout.keys {
            guard let count = counts[key.keyCode], count > 0 else { continue }
            switch key.hand {
            case .left: left += count
            case .right: right += count
            case .either:
                // Space is pressed by either thumb; split it evenly rather than biasing a side.
                left += count / 2
                right += count - count / 2
            }
            byRow[key.row, default: 0] += count
        }

        let handTotal = left + right
        let leftPercent = handTotal > 0 ? Int((Double(left) / Double(handTotal) * 100).rounded()) : 0

        let rowTotal = byRow.values.reduce(0, +)
        var rowShares: [KeyboardKey.Row: Int] = [:]
        if rowTotal > 0 {
            for (row, value) in byRow {
                rowShares[row] = Int((Double(value) / Double(rowTotal) * 100).rounded())
            }
        }
        return (leftPercent, rowShares)
    }

    /// Merges the per-app input tallies into display-ready profiles. App names come from the
    /// stored name map first so history stays readable after an app is uninstalled, falling back
    /// to whatever the usage records know.
    private static func appInputProfiles(raw: DailyRawCounters, usage: [AppUsageStat]) -> [AppInputProfile] {
        var bundleIDs = Set(raw.appKeyPresses.keys)
        bundleIDs.formUnion(raw.appClicks.keys)
        bundleIDs.formUnion(raw.appScrollPoints.keys)
        guard !bundleIDs.isEmpty else { return [] }

        let namesFromUsage = Dictionary(usage.map { ($0.bundleID, $0.appName) }, uniquingKeysWith: { a, _ in a })
        return bundleIDs.map { bundleID in
            AppInputProfile(
                bundleID: bundleID,
                appName: raw.appNames[bundleID] ?? namesFromUsage[bundleID] ?? bundleID,
                keyPresses: raw.appKeyPresses[bundleID] ?? 0,
                clicks: raw.appClicks[bundleID] ?? 0,
                scrollPoints: raw.appScrollPoints[bundleID] ?? 0
            )
        }
        .filter { $0.totalInput > 0 }
        .sorted { $0.totalInput > $1.totalInput }
    }

    /// How concentrated app time was. Uses a Herfindahl index (sum of squared shares), which is
    /// 100 when a single app took everything and approaches 0 when time was spread thin.
    private static func appConcentration(_ usage: [AppUsageStat]) -> (percent: Int, appsForHalf: Int) {
        let total = usage.reduce(0.0) { $0 + $1.totalSeconds }
        guard total > 0 else { return (0, 0) }

        var herfindahl = 0.0
        var running = 0.0
        var appsForHalf = 0
        for app in usage.sorted(by: { $0.totalSeconds > $1.totalSeconds }) {
            let share = app.totalSeconds / total
            herfindahl += share * share
            if running < total / 2 {
                running += app.totalSeconds
                appsForHalf += 1
            }
        }
        return (Int((herfindahl * 100).rounded()), appsForHalf)
    }

    /// How evenly typing was spread across the minutes it happened in. Computed as the inverse
    /// of the coefficient of variation, so a steady writer scores high and someone who typed
    /// everything in one frantic burst scores low.
    private static func typingConsistency(_ perMinute: [Int]) -> Int {
        let active = perMinute.filter { $0 > 0 }.map(Double.init)
        guard active.count >= 5 else { return 0 }
        let mean = active.reduce(0, +) / Double(active.count)
        guard mean > 0 else { return 0 }
        let variance = active.reduce(0) { $0 + pow($1 - mean, 2) } / Double(active.count)
        let coefficientOfVariation = variance.squareRoot() / mean
        return max(0, min(100, Int(((1 - min(coefficientOfVariation, 1.5) / 1.5) * 100).rounded())))
    }

    /// The clock hour with the highest sustained typing speed, and that speed in WPM.
    /// Only hours with a meaningful amount of typing are eligible.
    private static func goldenHour(_ charKeysPerMinute: [Int], dayStartHour: Int) -> (hour: Int, wpm: Double)? {
        guard charKeysPerMinute.count == 24 * 60 else { return nil }
        var best: (hour: Int, wpm: Double)?
        for hourIndex in 0..<24 {
            let slice = charKeysPerMinute[(hourIndex * 60)..<((hourIndex + 1) * 60)]
            let typedMinutes = slice.filter { $0 > 0 }.count
            guard typedMinutes >= 5 else { continue }
            let total = slice.reduce(0, +)
            // WPM over the minutes actually spent typing, not the whole hour.
            let wpm = Double(total) / 5.0 / Double(typedMinutes)
            if wpm > (best?.wpm ?? 0) {
                let wallHour = (hourIndex + dayStartHour) % 24
                best = (wallHour, wpm)
            }
        }
        return best
    }

    /// Longest gap between consecutive activity sessions — the day's biggest break.
    private static func longestBreak(_ sessions: [ActivitySessionRecord]) -> Int {
        guard sessions.count >= 2 else { return 0 }
        let sorted = sessions.sorted { $0.start < $1.start }
        var longest: TimeInterval = 0
        for (previous, next) in zip(sorted, sorted.dropFirst()) {
            longest = max(longest, next.start.timeIntervalSince(previous.end))
        }
        return Int(max(0, longest))
    }

    /// Total battery percentage consumed today, summing only the downward steps between
    /// consecutive samples so recharges don't cancel out the drain that preceded them.
    private static func batteryDrained(_ samples: [BatterySample]) -> Int {
        guard samples.count > 1 else { return 0 }
        var drained = 0
        for (previous, current) in zip(samples, samples.dropFirst()) {
            if current.level < previous.level {
                drained += previous.level - current.level
            }
        }
        return drained
    }

    private static func bestFocusHour(_ sessions: [FocusSessionRecord]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        var byHour: [Int: TimeInterval] = [:]
        let calendar = Calendar.current
        for session in sessions {
            let hour = calendar.component(.hour, from: session.start)
            byHour[hour, default: 0] += session.duration
        }
        return byHour.max { $0.value < $1.value }?.key
    }

    // MARK: - Derived indices (0...100, always presented as lighthearted, not scientific)

    private static func regretIndex(raw: DailyRawCounters, backspaceRatio: Double) -> Double {
        let undo = Double(raw.shortcutCounts[ShortcutType.undo.rawValue] ?? 0)
        let redo = Double(raw.shortcutCounts[ShortcutType.redo.rawValue] ?? 0)
        let selectAll = Double(raw.shortcutCounts[ShortcutType.selectAll.rawValue] ?? 0)
        let rawScore = undo * 3 + redo * 2 + selectAll * 1 + backspaceRatio * 100 * 0.6
        return min(100, rawScore)
    }

    private static func chaosIndex(raw: DailyRawCounters) -> Double {
        let switchesPerHour: Double
        if let first = raw.firstActivity, let last = raw.lastActivity, last > first {
            let hours = max(last.timeIntervalSince(first) / 3600, 0.25)
            switchesPerHour = Double(raw.totalAppSwitches) / hours
        } else {
            switchesPerHour = 0
        }
        let interruptions = Double(raw.focusInterruptionsByApp.values.reduce(0, +))
        let burstiness = burstinessScore(raw.activityPerMinute)
        let rawScore = switchesPerHour * 1.5 + Double(raw.shortDwellCount) * 2 + interruptions * 1.5 + burstiness * 20
        return min(100, rawScore)
    }

    /// How spiky the minute-by-minute activity is relative to its own average — a crude proxy
    /// for "sudden bursts of activity" without claiming to detect the user's actual mood.
    private static func burstinessScore(_ perMinute: [Int]) -> Double {
        let nonZero = perMinute.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        let avg = Double(nonZero.reduce(0, +)) / Double(nonZero.count)
        guard avg > 0, let peak = nonZero.max() else { return 0 }
        return min(3, Double(peak) / avg) / 3
    }

    /// Picks the day's tags. Candidates are scored per facet and only the strongest from each
    /// facet survives, so a day is never described three different ways of saying "you typed".
    private static func activityTags(raw: DailyRawCounters, summary: DailySummary) -> [ActivityTag] {
        var candidates: [(tag: ActivityTag, strength: Double)] = []

        func consider(_ tag: ActivityTag, when condition: Bool, strength: Double) {
            if condition { candidates.append((tag, strength)) }
        }

        // Typing style
        consider(.burstTyper,
                 when: summary.maxWPM > 55 && summary.avgWPM > 0 && summary.maxWPM > summary.avgWPM * 1.7,
                 strength: summary.maxWPM / max(summary.avgWPM, 1))
        consider(.steadyTyper,
                 when: raw.characterKeyPresses > 2500 && raw.longestTypingStreakSeconds > 480,
                 strength: Double(summary.typingConsistency) / 50)
        consider(.editorType,
                 when: summary.backspaceRatio > 0.22,
                 strength: summary.backspaceRatio * 4)

        // Pointer style
        consider(.mouseExplorer,
                 when: summary.cursorDistanceMeters > 400,
                 strength: summary.cursorDistanceMeters / 400)
        consider(.scrollTraveler,
                 when: summary.scrollScreens > 300,
                 strength: summary.scrollScreens / 300)

        // Efficiency habits
        let shortcutTotal = raw.shortcutCounts.values.reduce(0, +)
        consider(.shortcutExpert, when: shortcutTotal > 120, strength: Double(shortcutTotal) / 120)
        consider(.pasteHeavy, when: raw.clipboardPasteCount > 35, strength: Double(raw.clipboardPasteCount) / 35)

        // Attention shape
        consider(.focused,
                 when: summary.totalFocusSeconds > 3 * 3600 || summary.longestFocusSeconds > 90 * 60,
                 strength: Double(summary.totalFocusSeconds) / 3600)
        consider(.appHopper,
                 when: raw.totalAppSwitches > 120 || raw.shortDwellCount > 25,
                 strength: Double(raw.totalAppSwitches) / 120)
        consider(.chaotic, when: summary.chaosIndex > 65, strength: summary.chaosIndex / 65)

        // Rhythm of the day
        consider(.nightOwl, when: isNightOwl(raw: raw), strength: 1.5)
        consider(.earlyBird, when: isEarlyBird(raw: raw), strength: 1.4)
        consider(.marathoner, when: summary.activeSeconds > 6 * 3600,
                 strength: Double(summary.activeSeconds) / (6 * 3600))
        consider(.sprinter,
                 when: summary.activeSeconds < 2 * 3600 && summary.totalKeyPresses > 3000,
                 strength: Double(summary.totalKeyPresses) / 3000)

        // Machine & environment
        consider(.unplugged,
                 when: summary.secondsOnBattery > 3 * 3600 && summary.secondsOnBattery > summary.secondsOnAC,
                 strength: Double(summary.secondsOnBattery) / (3 * 3600))
        consider(.multiScreen, when: summary.maxSimultaneousDisplays >= 2,
                 strength: Double(summary.maxSimultaneousDisplays))
        consider(.dataHeavy, when: summary.networkTotalBytes > 3_000_000_000,
                 strength: Double(summary.networkTotalBytes) / 3_000_000_000)
        consider(.screenIdler,
                 when: summary.screenOnSeconds > 3600 && summary.screenUtilizationPercent < 30,
                 strength: Double(100 - summary.screenUtilizationPercent) / 50)

        // Strongest candidate per facet, then the strongest facets overall.
        var best: [ActivityTag.Facet: (tag: ActivityTag, strength: Double)] = [:]
        for candidate in candidates {
            let facet = candidate.tag.facet
            if let existing = best[facet], existing.strength >= candidate.strength { continue }
            best[facet] = candidate
        }

        let tags = best.values
            .sorted { $0.strength > $1.strength }
            .prefix(3)
            .map(\.tag)

        return tags.isEmpty ? [.steadyTyper] : Array(tags)
    }

    /// Any activity in the early-morning hours, before most of the day gets going.
    private static func isEarlyBird(raw: DailyRawCounters) -> Bool {
        guard let first = raw.firstActivity else { return false }
        let hour = Calendar.current.component(.hour, from: first)
        return hour >= 5 && hour < 8
    }

    private static func isNightOwl(raw: DailyRawCounters) -> Bool {
        let calendar = Calendar.current
        let nightHours: Set<Int> = [0, 1, 2, 3, 4]
        for session in raw.activitySessions {
            if nightHours.contains(calendar.component(.hour, from: session.start)) {
                return true
            }
        }
        return false
    }

    // MARK: - Highlights

    private static func highlights(raw: DailyRawCounters, summary: DailySummary, dayStartHour: Int) -> [Highlight] {
        var items: [Highlight] = []

        if let time = summary.maxWPMTime, summary.maxWPM > 0 {
            items.append(Highlight(
                icon: "bolt.fill",
                title: "가장 빨랐던 순간",
                detail: "\(Formatters.time(time))에 \(Formatters.wpm(summary.maxWPM))로 가장 빠르게 타이핑했어요."
            ))
        }

        if let longest = raw.focusSessions.max(by: { $0.duration < $1.duration }) {
            items.append(Highlight(
                icon: "target",
                title: "가장 오래 집중한 순간",
                detail: "\(Formatters.time(longest.start))부터 \(Formatters.longDuration(Int(longest.duration))) 동안 \(longest.primaryApp)에 집중했어요."
            ))
        }

        if let chaosMoment = chaosMoment(raw: raw, dayStartHour: dayStartHour) {
            items.append(Highlight(
                icon: "tornado",
                title: "가장 혼돈스러웠던 순간",
                detail: chaosMoment
            ))
        }

        if let minute = summary.busiestMinute,
           summary.busiestMinuteCount >= 20,
           let time = date(forMinute: minute, day: raw.day, dayStartHour: dayStartHour) {
            items.append(Highlight(
                icon: "flame",
                title: "가장 바빴던 1분",
                detail: "\(Formatters.time(time))에 1분 동안 \(summary.busiestMinuteCount)번의 입력이 몰렸어요."
            ))
        }

        if let app = summary.topApp, app.totalSeconds >= 600 {
            items.append(Highlight(
                icon: "crown",
                title: "오늘의 MVP 앱",
                detail: "\(app.appName)에서 \(Formatters.withObjectParticle(Formatters.longDuration(Int(app.totalSeconds)))) 보냈어요."
            ))
        }

        return items
    }

    private static func chaosMoment(raw: DailyRawCounters, dayStartHour: Int) -> String? {
        let calendar = Calendar.current
        var byHour: [Int: Int] = [:]
        for session in raw.appSessions {
            byHour[calendar.component(.hour, from: session.start), default: 0] += 1
        }
        if let peak = byHour.max(by: { $0.value < $1.value }), peak.value >= 3 {
            return "\(Formatters.approximateHourLabel(peak.key))에 앱을 \(peak.value)번 전환하며 분주하게 움직였어요."
        }
        if let peakMinute = raw.activityPerMinute.enumerated().max(by: { $0.element < $1.element }),
           peakMinute.element > 0,
           let time = date(forMinute: peakMinute.offset, day: raw.day, dayStartHour: dayStartHour) {
            return "\(Formatters.time(time))에 활동이 가장 몰려 있었어요."
        }
        return nil
    }

    // MARK: - Fun facts (approximate conversions)

    /// Builds the pool of "재미있는 사실". `FunConversions` owns the arithmetic and reference
    /// constants; this decides which categories are worth mentioning and tags each line with the
    /// quantity it describes so the UI can pick a varied set.
    private static func funFacts(raw: DailyRawCounters, summary: DailySummary) -> [FunFact] {
        var facts: [FunFact] = []

        facts += FunConversions.cursorFacts(meters: summary.cursorDistanceMeters)
        facts += FunConversions.scrollFacts(
            screens: summary.scrollScreens,
            screenHeightMeters: DisplayMetrics.shared.mainScreenHeightMeters
        )
        facts += FunConversions.keyboardFacts(
            characterKeys: summary.characterKeyPresses,
            totalKeys: summary.totalKeyPresses
        )
        facts += FunConversions.timeFacts(
            activeSeconds: summary.activeSeconds,
            focusSeconds: summary.totalFocusSeconds,
            screenOnSeconds: summary.screenOnSeconds
        )
        facts += FunConversions.clickFacts(
            totalClicks: summary.totalClicks,
            scrollDirectionChanges: summary.scrollDirectionChanges,
            activeSeconds: summary.activeSeconds
        )
        facts += summary.energyFacts
        facts += FunConversions.networkFacts(
            downloadBytes: summary.networkDownloadBytes,
            uploadBytes: summary.networkUploadBytes,
            peakDownPerSec: summary.peakDownloadBytesPerSec
        )

        func add(_ topic: FunFact.Topic, _ text: String) {
            facts.append(FunFact(topic: topic, text: text))
        }

        // Keyboard character
        if let key = summary.mostPressedKeyLabel, summary.mostPressedKeyCount > 20 {
            add(.keys, "오늘 가장 많이 누른 키는 \(key)였어요 (\(Formatters.groupedNumber(summary.mostPressedKeyCount))회)")
        }
        if summary.distinctKeysUsed >= 10 {
            add(.keys, "오늘 누른 키는 서로 다른 \(summary.distinctKeysUsed)종류였어요")
        }
        if summary.leftHandPercent > 0 {
            let left = summary.leftHandPercent
            if left >= 60 {
                add(.keys, "오늘 타이핑의 \(left)%를 왼손이 담당했어요")
            } else if left <= 40 {
                add(.keys, "오늘 타이핑의 \(100 - left)%를 오른손이 담당했어요")
            }
        }
        if let top = summary.keyCategoryCounts.max(by: { $0.value < $1.value }), top.value > 0 {
            add(.keys, "오늘 가장 많이 누른 키 종류는 \(keyCategoryLabel(top.key))였어요")
        }
        if let undo = summary.shortcutCounts[.undo], undo > 5 {
            add(.keys, "오늘 실행취소(Cmd+Z)를 \(undo)번 눌렀어요. 되돌리고 싶은 순간이 많았나 봐요")
        }
        if summary.distinctShortcutsUsed >= 5 {
            add(.keys, "오늘 사용한 단축키는 서로 다른 \(summary.distinctShortcutsUsed)종류였어요")
        }

        // Typing rhythm
        if summary.typingConsistency >= 70 {
            add(.typing, "오늘 타이핑 리듬의 일관성은 \(summary.typingConsistency)%로 아주 꾸준했어요")
        } else if summary.typingConsistency > 0 && summary.typingConsistency < 35 {
            add(.typing, "오늘 타이핑 리듬의 일관성은 \(summary.typingConsistency)%로, 몰아치듯 불규칙했어요")
        }
        if let hour = summary.goldenHour, summary.goldenHourWPM > 0 {
            add(.typing, String(format: "오늘 가장 빠르게 타이핑한 때는 %@이었어요 (평균 %.0f WPM)", Formatters.approximateHourLabel(hour), summary.goldenHourWPM))
        }

        // Screen & focus
        if summary.screenOnSeconds > 600, summary.screenUtilizationPercent > 0 {
            add(.screen, "오늘 화면이 켜져 있던 시간 중 \(summary.screenUtilizationPercent)%만 실제로 사용했어요")
        }
        if summary.longestBreakSeconds >= 3600 {
            add(.focus, "오늘 가장 길게 쉰 시간은 \(Formatters.compactDuration(summary.longestBreakSeconds))이었어요")
        }

        // Pointer detail
        if summary.dragDistanceMeters >= 5 {
            add(.pointer, String(format: "오늘 드래그로만 커서를 약 %.0fm 움직였어요", summary.dragDistanceMeters))
        }

        // Apps
        let totalAppSeconds = summary.appUsage.reduce(0) { $0 + $1.totalSeconds }
        if let app = summary.topApp, totalAppSeconds > 0 {
            let share = min(100, app.totalSeconds / totalAppSeconds * 100)
            if share >= 25 {
                add(.apps, String(format: "오늘 앱을 쓴 시간의 약 %.0f%%를 %@에서 보냈어요", share, app.appName))
            }
        }
        if let typing = summary.topTypingApp, typing.keyPresses > 100 {
            add(.apps, "오늘 가장 많이 타이핑한 앱은 \(typing.appName)이에요 (\(Formatters.compactNumber(typing.keyPresses))키)")
        }
        if let clicking = summary.topClickingApp, clicking.clicks > 50,
           clicking.bundleID != summary.topTypingApp?.bundleID {
            add(.apps, "오늘 가장 많이 클릭한 앱은 \(clicking.appName)이에요 (\(Formatters.compactNumber(clicking.clicks))번)")
        }
        if let typing = summary.topTypingApp, typing.totalInput > 200 {
            add(.apps, "\(typing.appName)에서는 \(typing.styleLabel)으로 작업했어요 (키보드 \(typing.keyboardSharePercent)%)")
        }

        if summary.shortDwellCount > 20 {
            add(.apps, "오늘 5초도 안 머물고 떠난 앱 방문이 \(summary.shortDwellCount)번 있었어요")
        }
        if summary.appConcentration >= 50, let app = summary.topApp {
            add(.apps, "오늘은 \(app.appName) 한 곳에 시간이 몰렸어요 (집중도 \(summary.appConcentration))")
        } else if summary.appsToReachHalfTime >= 4 {
            add(.apps, "오늘 앱 사용시간의 절반을 채우는 데 앱 \(summary.appsToReachHalfTime)개가 필요했어요")
        }

        // Power & device
        if summary.totalChargedPercent > 0 {
            add(.power, "오늘 \(summary.chargeSessionCount)번 충전해서 배터리를 \(summary.totalChargedPercent)% 채웠어요")
        }
        if summary.secondsOnBattery > 0 && summary.secondsOnAC > 0 {
            let share = Double(summary.secondsOnBattery) / Double(summary.secondsOnBattery + summary.secondsOnAC) * 100
            add(.power, String(format: "오늘 사용시간 중 약 %.0f%%를 배터리로 보냈어요", share))
        }
        if let cycles = summary.batteryCycleCount, let health = summary.batteryHealthPercent {
            add(.power, "이 Mac 배터리는 지금까지 충전 사이클 \(cycles)번을 돌았고 건강도는 \(health)%예요")
        }
        if summary.lowPowerModeSeconds > 60 {
            add(.power, "오늘 저전력 모드로 \(Formatters.withObjectParticle(Formatters.longDuration(summary.lowPowerModeSeconds))) 보냈어요")
        }
        if summary.sleepCount > 0 {
            add(.device, "오늘 Mac을 \(summary.sleepCount)번 재우고 \(summary.wakeCount)번 깨웠어요")
        }
        if summary.lidCloseCount > 0 {
            add(.device, "오늘 뚜껑을 \(summary.lidCloseCount)번 닫고 \(summary.lidOpenCount)번 열었어요")
        }
        if summary.externalDisplayConnectCount > 0 {
            add(.device, "오늘 외장 디스플레이를 \(summary.externalDisplayConnectCount)번 연결했어요")
        }
        if summary.audioOutputDeviceChangeCount > 2 {
            add(.device, "오늘 오디오 출력 장치를 \(summary.audioOutputDeviceChangeCount)번 바꿨어요")
        }

        return facts
    }

    private static func keyCategoryLabel(_ category: KeyCategory) -> String {
        switch category {
        case .character: return "문자 키"
        case .backspace: return "Backspace"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .enter: return "Enter"
        case .space: return "Space"
        case .tab: return "Tab"
        case .arrow: return "방향키"
        case .shift: return "Shift"
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .capsLock: return "Caps Lock"
        case .hangulSwitch: return "한영 전환"
        case .functionKey: return "기능 키"
        }
    }

    // MARK: - Summary sentence

    private static func summarySentence(raw: DailyRawCounters, summary: DailySummary, recentDays: [DailyRawCounters]) -> String {
        guard raw.totalKeyPresses > 0 || summary.activeSeconds > 0 else {
            return "아직 오늘의 활동 기록이 충분하지 않아요. Mac을 사용하면 여기에 이야기가 채워집니다."
        }

        var parts: [String] = []

        if !recentDays.isEmpty {
            let avgKeys = Double(recentDays.map(\.totalKeyPresses).reduce(0, +)) / Double(recentDays.count)
            if avgKeys > 0 {
                let diffPercent = ((Double(raw.totalKeyPresses) - avgKeys) / avgKeys) * 100
                if abs(diffPercent) >= 8 {
                    let direction = diffPercent >= 0 ? "더 많이" : "더 적게"
                    parts.append("오늘은 최근 평균보다 \(Int(abs(diffPercent)))% \(direction) 타이핑했습니다.")
                }
            }
        }

        if summary.maxWPM > 0, let time = summary.maxWPMTime {
            parts.append("\(Formatters.time(time))에 \(Formatters.wpm(summary.maxWPM))로 오늘의 최고 속도를 기록했습니다.")
        }

        if summary.longestFocusSeconds >= 300 {
            parts.append("가장 길게는 \(Formatters.longDuration(summary.longestFocusSeconds)) 동안 집중했습니다.")
        }

        if parts.isEmpty {
            parts.append("오늘도 Mac과 함께 여러 순간을 보냈습니다.")
        }

        return parts.prefix(2).joined(separator: " ")
    }

    // MARK: - Minute → Date

    private static func date(forMinute minute: Int, day: String, dayStartHour: Int) -> Date? {
        guard let dayDate = DayKey.date(fromDayString: day) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let shiftedMinutes = minute + dayStartHour * 60
        return calendar.date(byAdding: .minute, value: shiftedMinutes, to: dayDate)
    }
}
