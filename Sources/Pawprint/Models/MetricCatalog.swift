import Foundation

/// One displayable metric, declared **once**.
///
/// Everything that presents a metric — the Today dashboard cards, the activity calendar's
/// basis picker, the "오늘 vs 평소" comparison, the settings pickers — reads this catalog
/// instead of carrying its own enum. Adding a metric therefore means adding one entry here,
/// not editing eight files (spec §23 확장성 요구사항).
struct MetricDefinition: Identifiable, Hashable {
    /// Stable identifier persisted in settings. Never rename an existing one — old settings
    /// reference it by string.
    let id: String
    let title: String
    let icon: String
    let explanation: String
    /// Which collection toggle governs this metric. Used to hide metrics whose source is off.
    let category: CollectionCategory

    /// Numeric value for ranking, calendar shading, and averages.
    let value: (DailySummary) -> Double
    /// Human-readable rendering of that value.
    let display: (DailySummary) -> String

    /// Whether this metric can drive the activity calendar's colour scale. Metrics that are
    /// ratios or percentages make poor heat scales, so they opt out.
    var availableInCalendar: Bool = true
    /// Whether it can be chosen as one of the Today tab's headline cards.
    var availableAsCard: Bool = true
    /// Whether it's meaningful to compare against the recent average.
    var availableInComparison: Bool = false

    /// All-time total, when summing across days is meaningful. Powers the Records tab and,
    /// where a track exists, the level system.
    var lifetimeValue: ((LifetimeStats) -> Double)? = nil
    var lifetimeDisplay: ((LifetimeStats) -> String)? = nil

    static func == (lhs: MetricDefinition, rhs: MetricDefinition) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MetricCatalog {

    /// The single registry. Order here is the order shown in every picker.
    static let all: [MetricDefinition] = [
        // MARK: Time
        MetricDefinition(
            id: "activeTime",
            title: L10n.t("metricCatalog.e6bdb45b"),
            icon: "clock.fill",
            explanation: L10n.t("metricCatalog.dfb8fcab"),
            category: .appUsage,
            value: { Double($0.activeSeconds) },
            display: { Formatters.compactDuration($0.activeSeconds) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalActiveSeconds) },
            lifetimeDisplay: { Formatters.longSpan($0.totalActiveSeconds) }
        ),
        MetricDefinition(
            id: "screenOnTime",
            title: L10n.t("metricCatalog.e5e7450c"),
            icon: "display",
            explanation: MetricExplanations.screenTime.body,
            category: .sleepWake,
            value: { Double($0.screenOnSeconds) },
            display: { Formatters.compactDuration($0.screenOnSeconds) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalScreenOnSeconds) },
            lifetimeDisplay: { Formatters.longSpan($0.totalScreenOnSeconds) }
        ),
        MetricDefinition(
            id: "screenUtilization",
            title: L10n.t("metricCatalog.a4db1d38"),
            icon: "gauge.medium",
            explanation: L10n.t("metricCatalog.e4702cd7"),
            category: .sleepWake,
            value: { Double($0.screenUtilizationPercent) },
            display: { $0.screenOnSeconds > 0 ? "\($0.screenUtilizationPercent)%" : "-" },
            availableInCalendar: false
        ),
        MetricDefinition(
            id: "focusTime",
            title: L10n.t("metricCatalog.77bad0ab"),
            icon: "target",
            explanation: MetricExplanations.focus.body,
            category: .appUsage,
            value: { Double($0.totalFocusSeconds) },
            display: { Formatters.compactDuration($0.totalFocusSeconds) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalFocusSeconds) },
            lifetimeDisplay: { Formatters.longSpan($0.totalFocusSeconds) }
        ),
        MetricDefinition(
            id: "longestFocus",
            title: L10n.t("metricCatalog.57beed03"),
            icon: "scope",
            explanation: L10n.t("metricCatalog.df234c85"),
            category: .appUsage,
            value: { Double($0.longestFocusSeconds) },
            display: { $0.longestFocusSeconds > 0 ? Formatters.compactDuration($0.longestFocusSeconds) : "-" }
        ),

        // MARK: Keyboard
        MetricDefinition(
            id: "totalKeys",
            title: L10n.t("metricCatalog.ebcbe122"),
            icon: "keyboard",
            explanation: L10n.t("metricCatalog.8b6bf2d3"),
            category: .keyboard,
            value: { Double($0.totalKeyPresses) },
            display: { Formatters.compactNumber($0.totalKeyPresses) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalKeyPresses) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalKeyPresses) }
        ),
        MetricDefinition(
            id: "maxWPM",
            title: L10n.t("metricCatalog.99e3df8c"),
            icon: "bolt.fill",
            explanation: L10n.t("metricCatalog.b26c159f"),
            category: .keyboard,
            value: { $0.maxWPM },
            display: { $0.maxWPM > 0 ? Formatters.wpm($0.maxWPM) : "-" },
            availableInCalendar: false,
            availableInComparison: true
        ),
        MetricDefinition(
            id: "typingConsistency",
            title: L10n.t("metricCatalog.99bb387e"),
            icon: "waveform.path",
            explanation: L10n.t("metricCatalog.2a4a07dc"),
            category: .keyboard,
            value: { Double($0.typingConsistency) },
            display: { $0.typingConsistency > 0 ? "\($0.typingConsistency)%" : "-" },
            availableInCalendar: false
        ),
        MetricDefinition(
            id: "shortcuts",
            title: L10n.t("metricCatalog.4ca8229c"),
            icon: "command",
            explanation: L10n.t("metricCatalog.b0fcd9e3"),
            category: .keyboard,
            value: { Double($0.shortcutCounts.values.reduce(0, +)) },
            display: { Formatters.groupedNumber($0.shortcutCounts.values.reduce(0, +)) },
            lifetimeValue: { Double($0.shortcutTotal) },
            lifetimeDisplay: { Formatters.compactNumber($0.shortcutTotal) }
        ),

        // MARK: Pointer
        MetricDefinition(
            id: "totalClicks",
            title: L10n.t("metricCatalog.900f26cb"),
            icon: "cursorarrow.click",
            explanation: L10n.t("metricCatalog.ae86bdaf"),
            category: .mouse,
            value: { Double($0.totalClicks) },
            display: { Formatters.compactNumber($0.totalClicks) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalClicks) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalClicks) }
        ),
        MetricDefinition(
            id: "cursorDistance",
            title: L10n.t("metricCatalog.314017fc"),
            icon: "figure.run",
            explanation: L10n.t("metricCatalog.560ab027"),
            category: .mouse,
            value: { $0.cursorDistanceMeters },
            display: { Formatters.compactDistance(meters: $0.cursorDistanceMeters) },
            lifetimeValue: { $0.cursorDistanceMeters },
            lifetimeDisplay: { Formatters.compactDistance(meters: $0.cursorDistanceMeters) }
        ),
        MetricDefinition(
            id: "scrollAmount",
            title: L10n.t("metricCatalog.00adcaf0"),
            icon: "scroll",
            explanation: L10n.t("metricCatalog.472edd57"),
            category: .mouse,
            value: { $0.scrollScreens },
            display: { Formatters.compactNumber(Int($0.scrollScreens.rounded())) + L10n.t("metricCatalog.43c786f1") },
            lifetimeValue: { $0.scrollScreens },
            lifetimeDisplay: { Formatters.compactNumber(Int($0.scrollScreens.rounded())) + L10n.t("metricCatalog.43c786f1") }
        ),

        // MARK: Apps
        MetricDefinition(
            id: "appSwitches",
            title: L10n.t("metricCatalog.f77d9ebb"),
            icon: "arrow.left.arrow.right",
            explanation: L10n.t("metricCatalog.96bcdc56"),
            category: .appUsage,
            value: { Double($0.totalAppSwitches) },
            display: { Formatters.groupedNumber($0.totalAppSwitches) },
            lifetimeValue: { Double($0.totalAppSwitches) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalAppSwitches) }
        ),
        MetricDefinition(
            id: "appConcentration",
            title: L10n.t("metricCatalog.c8d17c79"),
            icon: "chart.pie.fill",
            explanation: MetricExplanations.appConcentration.body,
            category: .appUsage,
            value: { Double($0.appConcentration) },
            display: { $0.appConcentration > 0 ? "\($0.appConcentration)/100" : "-" },
            availableInCalendar: false
        ),

        // MARK: Clipboard
        MetricDefinition(
            id: "clipboard",
            title: L10n.t("metricCatalog.00b3e1ca"),
            icon: "doc.on.clipboard",
            explanation: L10n.t("metricCatalog.dafd6e9c"),
            category: .clipboard,
            value: { Double($0.clipboardCopyCount + $0.clipboardPasteCount) },
            display: { "\($0.clipboardCopyCount) / \($0.clipboardPasteCount)" },
            lifetimeValue: { Double($0.clipboardCopyCount + $0.clipboardPasteCount) },
            lifetimeDisplay: { Formatters.compactNumber($0.clipboardCopyCount + $0.clipboardPasteCount) }
        ),

        // MARK: Power
        MetricDefinition(
            id: "batteryUsed",
            title: L10n.t("metricCatalog.81bdc1fb"),
            icon: "battery.25",
            explanation: MetricExplanations.energy.body,
            category: .powerPeripherals,
            value: { Double($0.batteryDrainedPercent) },
            display: { $0.batteryDrainedPercent > 0 ? "\($0.batteryDrainedPercent)%" : "-" }
        ),
        MetricDefinition(
            id: "batteryTime",
            title: L10n.t("metricCatalog.4cbcb836"),
            icon: "battery.100.bolt",
            explanation: L10n.t("metricCatalog.70017495"),
            category: .powerPeripherals,
            value: { Double($0.secondsOnBattery) },
            display: { Formatters.compactDuration($0.secondsOnBattery) }
        ),
        MetricDefinition(
            id: "sleepCount",
            title: L10n.t("metricCatalog.642e4659"),
            icon: "moon.zzz",
            explanation: L10n.t("metricCatalog.3cc2c92e"),
            category: .sleepWake,
            value: { Double($0.sleepCount) },
            display: { L10n.t("metricCatalog.cf3d71b3", $0.sleepCount) }
        ),
        MetricDefinition(
            id: "lidCloses",
            title: L10n.t("metricCatalog.e5723771"),
            icon: "laptopcomputer.and.arrow.down",
            explanation: L10n.t("metricCatalog.52d7858e"),
            category: .powerPeripherals,
            value: { Double($0.lidCloseCount) },
            display: { L10n.t("metricCatalog.cf3d71b3", $0.lidCloseCount) }
        ),

        // MARK: Network
        MetricDefinition(
            id: "networkTotal",
            title: L10n.t("metricCatalog.d182eb6a"),
            icon: "network",
            explanation: MetricExplanations.network.body,
            category: .powerPeripherals,
            value: { Double($0.networkTotalBytes) },
            display: { Formatters.bytes($0.networkTotalBytes) },
            availableInComparison: true,
            lifetimeValue: { Double($0.networkDownloadBytes + $0.networkUploadBytes) },
            lifetimeDisplay: { Formatters.bytes($0.networkDownloadBytes + $0.networkUploadBytes) }
        ),
        MetricDefinition(
            id: "networkDownload",
            title: L10n.t("metricCatalog.5c5095ab"),
            icon: "arrow.down.circle",
            explanation: L10n.t("metricCatalog.fff554f2"),
            category: .powerPeripherals,
            value: { Double($0.networkDownloadBytes) },
            display: { Formatters.bytes($0.networkDownloadBytes) },
            lifetimeValue: { Double($0.networkDownloadBytes) },
            lifetimeDisplay: { Formatters.bytes($0.networkDownloadBytes) }
        ),
        MetricDefinition(
            id: "networkUpload",
            title: L10n.t("metricCatalog.51672ccd"),
            icon: "arrow.up.circle",
            explanation: L10n.t("metricCatalog.456156da"),
            category: .powerPeripherals,
            value: { Double($0.networkUploadBytes) },
            display: { Formatters.bytes($0.networkUploadBytes) },
            lifetimeValue: { Double($0.networkUploadBytes) },
            lifetimeDisplay: { Formatters.bytes($0.networkUploadBytes) }
        ),
    ]

    private static let byID: [String: MetricDefinition] = {
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    static func metric(id: String) -> MetricDefinition? { byID[id] }

    static var calendarMetrics: [MetricDefinition] { all.filter(\.availableInCalendar) }
    static var cardMetrics: [MetricDefinition] { all.filter(\.availableAsCard) }
    static var comparisonMetrics: [MetricDefinition] { all.filter(\.availableInComparison) }
    static var lifetimeMetrics: [MetricDefinition] { all.filter { $0.lifetimeValue != nil } }

    /// Metrics whose source category the user currently has switched on. Showing a metric that
    /// can't collect anything would just be a permanently empty card.
    static func enabled(_ metrics: [MetricDefinition], settings: AppSettings) -> [MetricDefinition] {
        metrics.filter { settings.isCollecting($0.category) }
    }

    static let defaultCardIDs = ["maxWPM", "totalKeys", "longestFocus", "activeTime"]
    static let defaultCalendarID = "activeTime"
    static let defaultShareIDs = [
        "activeTime", "screenOnTime", "totalKeys", "maxWPM",
        "longestFocus", "totalClicks", "cursorDistance", "scrollAmount",
    ]

    /// Share-card metrics the user has chosen, resolved and filtered to what's still collectable.
    static func shareMetrics(settings: AppSettings) -> [MetricDefinition] {
        let chosen = settings.shareCardMetricIDs.compactMap { metric(id: $0) }
        let usable = chosen.filter { settings.isCollecting($0.category) }
        let resolved = usable.isEmpty ? defaultShareIDs.compactMap { metric(id: $0) } : usable
        return Array(resolved.prefix(AppSettings.maxShareCardMetrics))
    }
}
