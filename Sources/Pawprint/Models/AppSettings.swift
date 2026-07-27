import Foundation

enum MenuBarMetric: String, Codable, CaseIterable {
    case iconOnly
    case wpm
    case totalKeys
    case focusTime
    case activeTime
    case undoCount

    var label: String {
        switch self {
        case .iconOnly: return "아이콘만"
        case .wpm: return "최고 타자 속도"
        case .totalKeys: return "전체 키 입력"
        case .focusTime: return "최장 집중시간"
        case .activeTime: return "활성 사용시간"
        case .undoCount: return "Undo 횟수"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }
}

struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var displayName: String
    var isDefault: Bool = false
}

/// User preferences.
///
/// Decoding is hand-written with `decodeIfPresent` for the same reason as `DailyRawCounters`:
/// Swift's synthesized `Decodable` throws `keyNotFound` for any missing field even when the
/// property has a default, and `PawprintStore.loadSettings` swallows that with `try?` — so
/// adding a single new preference would silently reset *every* setting the user had chosen.
struct AppSettings: Codable {
    var launchAtLogin: Bool = false
    var showDockIcon: Bool = false
    var menuBarMetric: MenuBarMetric = .wpm
    var dayStartHour: Int = 0
    var theme: AppTheme = .system

    var collectKeyboard: Bool = true
    var collectMouse: Bool = true
    var collectAppUsage: Bool = true
    var collectClipboard: Bool = true
    var collectSleepWake: Bool = true
    var collectPowerPeripherals: Bool = true

    var isPaused: Bool = false

    var excludedApps: [ExcludedApp] = AppSettings.defaultExcludedApps
    var focusThresholdSeconds: Int = 5 * 60
    /// Days of history to keep. 0 means keep forever.
    var retentionDays: Int = 90

    /// Headline cards on the Today tab, stored as `MetricCatalog` ids.
    var dashboardCardIDs: [String] = MetricCatalog.defaultCardIDs
    /// Which metric shades the activity calendar, as a `MetricCatalog` id.
    var calendarMetricID: String = MetricCatalog.defaultCalendarID
    /// Metrics shown on the shareable card, as `MetricCatalog` ids.
    var shareCardMetricIDs: [String] = MetricCatalog.defaultShareIDs

    /// Opt-in daily recap notification. Off by default — the app should never nag.
    var dailySummaryEnabled: Bool = false
    var dailySummaryHour: Int = 21
    var dailySummaryMinute: Int = 0
    /// Quiet celebration when a level track advances or a personal record falls.
    var celebrationNotificationsEnabled: Bool = false

    /// Highest level already announced per quest track, persisted so a relaunch doesn't re-fire
    /// notifications the user has already seen. In-memory state was not enough: every rebuild or
    /// restart re-armed them.
    var notifiedQuestLevels: [String: Int] = [:]
    /// Day and running count for the per-day cap.
    var notificationDay: String = ""
    var notificationCountToday: Int = 0
    /// Even a genuinely productive day shouldn't produce a stream of alerts.
    static let maxAchievementNotificationsPerDay = 2

    // MARK: Live HUD
    var hudCompact: Bool = false
    /// 0.35...1.0. Below ~0.35 the text stops being legible.
    var hudOpacity: Double = 1.0
    /// Today-metrics shown under the gauge, as `MetricCatalog` ids.
    var hudMetricIDs: [String] = ["totalKeys", "focusTime"]
    /// Session rows are separate from the catalog — they describe the current stretch of work,
    /// which has no all-day equivalent.
    var hudShowsSessionTime: Bool = true
    var hudShowsSessionKeys: Bool = true
    var hudShowsSessionClicks: Bool = true

    // MARK: - First run

    /// Set once the setup wizard has been shown, so it never nags on later launches.
    var hasCompletedOnboarding: Bool = false

    // MARK: - Updates

    /// Off by default. Pawprint promises to work fully offline and to make no request the user
    /// didn't ask for — an update check is still a network request, so it stays opt-in.
    var updateCheckEnabled: Bool = false
    /// Feed URL. Ships empty so a fresh install can't be pointed anywhere unexpected.
    var updateFeedURL: String = ""
    /// Skip the daily background check but keep the manual button working.
    var updateCheckAutomatically: Bool = true

    static let maxHUDMetrics = 4

    static let maxDashboardCards = 6
    /// The share card lays out a 4-wide grid; 8 keeps it to two tidy rows.
    static let maxShareCardMetrics = 8

    init() {}

    func isCollecting(_ category: CollectionCategory) -> Bool {
        switch category {
        case .keyboard: return collectKeyboard
        case .mouse: return collectMouse
        case .appUsage: return collectAppUsage
        case .clipboard: return collectClipboard
        case .sleepWake: return collectSleepWake
        case .powerPeripherals: return collectPowerPeripherals
        }
    }

    private enum CodingKeys: String, CodingKey {
        case notifiedQuestLevels, notificationDay, notificationCountToday
        case hasCompletedOnboarding
        case updateCheckEnabled, updateFeedURL, updateCheckAutomatically
        case launchAtLogin, showDockIcon, menuBarMetric, dayStartHour, theme
        case collectKeyboard, collectMouse, collectAppUsage, collectClipboard
        case collectSleepWake, collectPowerPeripherals
        case isPaused, excludedApps, focusThresholdSeconds, retentionDays
        case dashboardCardIDs, calendarMetricID, shareCardMetricIDs
        case dailySummaryEnabled, dailySummaryHour, dailySummaryMinute, celebrationNotificationsEnabled
        case hudCompact, hudOpacity, hudMetricIDs
        case hudShowsSessionTime, hudShowsSessionKeys, hudShowsSessionClicks
        /// Pre-catalog key: an array of `DashboardCardType` raw values. Ids were kept identical,
        /// so migration is a straight read-through.
        case dashboardCards
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()

        notifiedQuestLevels = try c.decodeIfPresent([String: Int].self, forKey: .notifiedQuestLevels) ?? fallback.notifiedQuestLevels
        notificationDay = try c.decodeIfPresent(String.self, forKey: .notificationDay) ?? fallback.notificationDay
        notificationCountToday = try c.decodeIfPresent(Int.self, forKey: .notificationCountToday) ?? fallback.notificationCountToday
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? fallback.hasCompletedOnboarding
        updateCheckEnabled = try c.decodeIfPresent(Bool.self, forKey: .updateCheckEnabled) ?? fallback.updateCheckEnabled
        updateFeedURL = try c.decodeIfPresent(String.self, forKey: .updateFeedURL) ?? fallback.updateFeedURL
        updateCheckAutomatically = try c.decodeIfPresent(Bool.self, forKey: .updateCheckAutomatically) ?? fallback.updateCheckAutomatically
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        showDockIcon = try c.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? fallback.showDockIcon
        menuBarMetric = try c.decodeIfPresent(MenuBarMetric.self, forKey: .menuBarMetric) ?? fallback.menuBarMetric
        dayStartHour = try c.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? fallback.dayStartHour
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? fallback.theme

        collectKeyboard = try c.decodeIfPresent(Bool.self, forKey: .collectKeyboard) ?? fallback.collectKeyboard
        collectMouse = try c.decodeIfPresent(Bool.self, forKey: .collectMouse) ?? fallback.collectMouse
        collectAppUsage = try c.decodeIfPresent(Bool.self, forKey: .collectAppUsage) ?? fallback.collectAppUsage
        collectClipboard = try c.decodeIfPresent(Bool.self, forKey: .collectClipboard) ?? fallback.collectClipboard
        collectSleepWake = try c.decodeIfPresent(Bool.self, forKey: .collectSleepWake) ?? fallback.collectSleepWake
        collectPowerPeripherals = try c.decodeIfPresent(Bool.self, forKey: .collectPowerPeripherals) ?? fallback.collectPowerPeripherals

        isPaused = try c.decodeIfPresent(Bool.self, forKey: .isPaused) ?? fallback.isPaused
        excludedApps = try c.decodeIfPresent([ExcludedApp].self, forKey: .excludedApps) ?? fallback.excludedApps
        focusThresholdSeconds = try c.decodeIfPresent(Int.self, forKey: .focusThresholdSeconds) ?? fallback.focusThresholdSeconds
        retentionDays = try c.decodeIfPresent(Int.self, forKey: .retentionDays) ?? fallback.retentionDays

        let storedIDs = try c.decodeIfPresent([String].self, forKey: .dashboardCardIDs)
            ?? c.decodeIfPresent([String].self, forKey: .dashboardCards)
        // Drop ids that no longer exist in the catalog so a removed metric can't leave a blank card.
        let valid = (storedIDs ?? fallback.dashboardCardIDs).filter { MetricCatalog.metric(id: $0) != nil }
        dashboardCardIDs = valid.isEmpty ? fallback.dashboardCardIDs : valid

        dailySummaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailySummaryEnabled) ?? fallback.dailySummaryEnabled
        dailySummaryHour = try c.decodeIfPresent(Int.self, forKey: .dailySummaryHour) ?? fallback.dailySummaryHour
        dailySummaryMinute = try c.decodeIfPresent(Int.self, forKey: .dailySummaryMinute) ?? fallback.dailySummaryMinute
        celebrationNotificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .celebrationNotificationsEnabled) ?? fallback.celebrationNotificationsEnabled

        hudCompact = try c.decodeIfPresent(Bool.self, forKey: .hudCompact) ?? fallback.hudCompact
        hudOpacity = min(1.0, max(0.35, try c.decodeIfPresent(Double.self, forKey: .hudOpacity) ?? fallback.hudOpacity))
        let storedHUD = try c.decodeIfPresent([String].self, forKey: .hudMetricIDs)
        let validHUD = (storedHUD ?? fallback.hudMetricIDs).filter { MetricCatalog.metric(id: $0) != nil }
        hudMetricIDs = Array(validHUD.prefix(AppSettings.maxHUDMetrics))
        hudShowsSessionTime = try c.decodeIfPresent(Bool.self, forKey: .hudShowsSessionTime) ?? fallback.hudShowsSessionTime
        hudShowsSessionKeys = try c.decodeIfPresent(Bool.self, forKey: .hudShowsSessionKeys) ?? fallback.hudShowsSessionKeys
        hudShowsSessionClicks = try c.decodeIfPresent(Bool.self, forKey: .hudShowsSessionClicks) ?? fallback.hudShowsSessionClicks

        let storedShare = try c.decodeIfPresent([String].self, forKey: .shareCardMetricIDs)
        let validShare = (storedShare ?? fallback.shareCardMetricIDs).filter { MetricCatalog.metric(id: $0) != nil }
        shareCardMetricIDs = validShare.isEmpty ? fallback.shareCardMetricIDs : validShare

        let storedCalendar = try c.decodeIfPresent(String.self, forKey: .calendarMetricID)
        calendarMetricID = storedCalendar.flatMap { MetricCatalog.metric(id: $0) != nil ? $0 : nil }
            ?? fallback.calendarMetricID
    }

    /// Written explicitly because the custom `init(from:)` suppresses synthesis. The legacy
    /// `dashboardCards` key is intentionally not written back — reading it is migration-only.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(notifiedQuestLevels, forKey: .notifiedQuestLevels)
        try c.encode(notificationDay, forKey: .notificationDay)
        try c.encode(notificationCountToday, forKey: .notificationCountToday)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(updateCheckEnabled, forKey: .updateCheckEnabled)
        try c.encode(updateFeedURL, forKey: .updateFeedURL)
        try c.encode(updateCheckAutomatically, forKey: .updateCheckAutomatically)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(showDockIcon, forKey: .showDockIcon)
        try c.encode(menuBarMetric, forKey: .menuBarMetric)
        try c.encode(dayStartHour, forKey: .dayStartHour)
        try c.encode(theme, forKey: .theme)
        try c.encode(collectKeyboard, forKey: .collectKeyboard)
        try c.encode(collectMouse, forKey: .collectMouse)
        try c.encode(collectAppUsage, forKey: .collectAppUsage)
        try c.encode(collectClipboard, forKey: .collectClipboard)
        try c.encode(collectSleepWake, forKey: .collectSleepWake)
        try c.encode(collectPowerPeripherals, forKey: .collectPowerPeripherals)
        try c.encode(isPaused, forKey: .isPaused)
        try c.encode(excludedApps, forKey: .excludedApps)
        try c.encode(focusThresholdSeconds, forKey: .focusThresholdSeconds)
        try c.encode(retentionDays, forKey: .retentionDays)
        try c.encode(dashboardCardIDs, forKey: .dashboardCardIDs)
        try c.encode(calendarMetricID, forKey: .calendarMetricID)
        try c.encode(shareCardMetricIDs, forKey: .shareCardMetricIDs)
        try c.encode(dailySummaryEnabled, forKey: .dailySummaryEnabled)
        try c.encode(dailySummaryHour, forKey: .dailySummaryHour)
        try c.encode(dailySummaryMinute, forKey: .dailySummaryMinute)
        try c.encode(celebrationNotificationsEnabled, forKey: .celebrationNotificationsEnabled)
        try c.encode(hudCompact, forKey: .hudCompact)
        try c.encode(hudOpacity, forKey: .hudOpacity)
        try c.encode(hudMetricIDs, forKey: .hudMetricIDs)
        try c.encode(hudShowsSessionTime, forKey: .hudShowsSessionTime)
        try c.encode(hudShowsSessionKeys, forKey: .hudShowsSessionKeys)
        try c.encode(hudShowsSessionClicks, forKey: .hudShowsSessionClicks)
    }

    static let defaultExcludedApps: [ExcludedApp] = [
        ExcludedApp(bundleID: "com.apple.Terminal", displayName: "터미널", isDefault: true),
        ExcludedApp(bundleID: "com.googlecode.iterm2", displayName: "iTerm2", isDefault: true),
        ExcludedApp(bundleID: "com.apple.RemoteDesktop", displayName: "원격 데스크톱 (호스트)", isDefault: true),
        ExcludedApp(bundleID: "com.apple.ScreenSharing", displayName: "화면 공유", isDefault: true),
        ExcludedApp(bundleID: "com.agilebits.onepassword7", displayName: "1Password 7", isDefault: true),
        ExcludedApp(bundleID: "com.1password.1password", displayName: "1Password", isDefault: true),
        ExcludedApp(bundleID: "com.lastpass.LastPass", displayName: "LastPass", isDefault: true),
        ExcludedApp(bundleID: "com.bitwarden.desktop", displayName: "Bitwarden", isDefault: true),
    ]
}
