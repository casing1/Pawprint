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
            title: "활성 사용시간",
            icon: "clock.fill",
            explanation: "실제로 입력이 있었던 시간의 합계예요. 자리를 비운 시간은 빠집니다.",
            category: .appUsage,
            value: { Double($0.activeSeconds) },
            display: { Formatters.compactDuration($0.activeSeconds) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalActiveSeconds) },
            lifetimeDisplay: { Formatters.longSpan($0.totalActiveSeconds) }
        ),
        MetricDefinition(
            id: "screenOnTime",
            title: "화면 켜짐 시간",
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
            title: "화면 활용도",
            icon: "gauge.medium",
            explanation: "화면이 켜져 있던 시간 중 실제로 입력이 있었던 비율이에요.",
            category: .sleepWake,
            value: { Double($0.screenUtilizationPercent) },
            display: { $0.screenOnSeconds > 0 ? "\($0.screenUtilizationPercent)%" : "-" },
            availableInCalendar: false
        ),
        MetricDefinition(
            id: "focusTime",
            title: "집중시간",
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
            title: "최장 집중시간",
            icon: "scope",
            explanation: "오늘 가장 길게 이어진 집중 세션 하나의 길이예요.",
            category: .appUsage,
            value: { Double($0.longestFocusSeconds) },
            display: { $0.longestFocusSeconds > 0 ? Formatters.compactDuration($0.longestFocusSeconds) : "-" }
        ),

        // MARK: Keyboard
        MetricDefinition(
            id: "totalKeys",
            title: "전체 키 입력",
            icon: "keyboard",
            explanation: "누른 모든 키의 횟수예요. 어떤 키였는지 순서나 내용은 저장하지 않아요.",
            category: .keyboard,
            value: { Double($0.totalKeyPresses) },
            display: { Formatters.compactNumber($0.totalKeyPresses) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalKeyPresses) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalKeyPresses) }
        ),
        MetricDefinition(
            id: "maxWPM",
            title: "최고 타자 속도",
            icon: "bolt.fill",
            explanation: "1분 동안 입력한 문자 키 수를 기준으로 계산한 그날의 최고 속도예요.",
            category: .keyboard,
            value: { $0.maxWPM },
            display: { $0.maxWPM > 0 ? Formatters.wpm($0.maxWPM) : "-" },
            availableInCalendar: false,
            availableInComparison: true
        ),
        MetricDefinition(
            id: "typingConsistency",
            title: "타이핑 일관성",
            icon: "waveform.path",
            explanation: "타이핑이 시간에 걸쳐 얼마나 고르게 이뤄졌는지를 0~100으로 나타내요.",
            category: .keyboard,
            value: { Double($0.typingConsistency) },
            display: { $0.typingConsistency > 0 ? "\($0.typingConsistency)%" : "-" },
            availableInCalendar: false
        ),
        MetricDefinition(
            id: "shortcuts",
            title: "단축키 사용",
            icon: "command",
            explanation: "복사·붙여넣기·실행취소 등 OS 전역 단축키를 누른 횟수예요.",
            category: .keyboard,
            value: { Double($0.shortcutCounts.values.reduce(0, +)) },
            display: { Formatters.groupedNumber($0.shortcutCounts.values.reduce(0, +)) },
            lifetimeValue: { Double($0.shortcutTotal) },
            lifetimeDisplay: { Formatters.compactNumber($0.shortcutTotal) }
        ),

        // MARK: Pointer
        MetricDefinition(
            id: "totalClicks",
            title: "클릭 수",
            icon: "cursorarrow.click",
            explanation: "좌클릭·우클릭·더블클릭을 모두 더한 횟수예요.",
            category: .mouse,
            value: { Double($0.totalClicks) },
            display: { Formatters.compactNumber($0.totalClicks) },
            availableInComparison: true,
            lifetimeValue: { Double($0.totalClicks) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalClicks) }
        ),
        MetricDefinition(
            id: "cursorDistance",
            title: "커서 이동 거리",
            icon: "figure.run",
            explanation: "커서가 움직인 거리를 이 Mac 화면의 실제 물리 크기 기준으로 환산했어요.",
            category: .mouse,
            value: { $0.cursorDistanceMeters },
            display: { Formatters.compactDistance(meters: $0.cursorDistanceMeters) },
            lifetimeValue: { $0.cursorDistanceMeters },
            lifetimeDisplay: { Formatters.compactDistance(meters: $0.cursorDistanceMeters) }
        ),
        MetricDefinition(
            id: "scrollAmount",
            title: "스크롤량",
            icon: "scroll",
            explanation: "스크롤한 거리를 화면 높이 단위로 환산한 값이에요.",
            category: .mouse,
            value: { $0.scrollScreens },
            display: { Formatters.compactNumber(Int($0.scrollScreens.rounded())) + "화면" },
            lifetimeValue: { $0.scrollScreens },
            lifetimeDisplay: { Formatters.compactNumber(Int($0.scrollScreens.rounded())) + "화면" }
        ),

        // MARK: Apps
        MetricDefinition(
            id: "appSwitches",
            title: "앱 전환 횟수",
            icon: "arrow.left.arrow.right",
            explanation: "다른 앱으로 전환한 횟수예요.",
            category: .appUsage,
            value: { Double($0.totalAppSwitches) },
            display: { Formatters.groupedNumber($0.totalAppSwitches) },
            lifetimeValue: { Double($0.totalAppSwitches) },
            lifetimeDisplay: { Formatters.compactNumber($0.totalAppSwitches) }
        ),
        MetricDefinition(
            id: "appConcentration",
            title: "앱 집중도",
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
            title: "복사·붙여넣기",
            icon: "doc.on.clipboard",
            explanation: "복사와 붙여넣기 횟수의 합계예요. 클립보드 내용은 저장하지 않아요.",
            category: .clipboard,
            value: { Double($0.clipboardCopyCount + $0.clipboardPasteCount) },
            display: { "\($0.clipboardCopyCount) / \($0.clipboardPasteCount)" },
            lifetimeValue: { Double($0.clipboardCopyCount + $0.clipboardPasteCount) },
            lifetimeDisplay: { Formatters.compactNumber($0.clipboardCopyCount + $0.clipboardPasteCount) }
        ),

        // MARK: Power
        MetricDefinition(
            id: "batteryUsed",
            title: "사용한 배터리",
            icon: "battery.25",
            explanation: MetricExplanations.energy.body,
            category: .powerPeripherals,
            value: { Double($0.batteryDrainedPercent) },
            display: { $0.batteryDrainedPercent > 0 ? "\($0.batteryDrainedPercent)%" : "-" }
        ),
        MetricDefinition(
            id: "batteryTime",
            title: "배터리 사용시간",
            icon: "battery.100.bolt",
            explanation: "충전기를 꽂지 않고 배터리로 사용한 시간이에요.",
            category: .powerPeripherals,
            value: { Double($0.secondsOnBattery) },
            display: { Formatters.compactDuration($0.secondsOnBattery) }
        ),
        MetricDefinition(
            id: "sleepCount",
            title: "잠자기 횟수",
            icon: "moon.zzz",
            explanation: "Mac이 잠자기 상태로 전환된 횟수예요.",
            category: .sleepWake,
            value: { Double($0.sleepCount) },
            display: { "\($0.sleepCount)회" }
        ),
        MetricDefinition(
            id: "lidCloses",
            title: "뚜껑 닫은 횟수",
            icon: "laptopcomputer.and.arrow.down",
            explanation: "뚜껑을 닫아도 Mac이 깨어 있는 경우(외장 모니터 연결 등)만 집계돼요.",
            category: .powerPeripherals,
            value: { Double($0.lidCloseCount) },
            display: { "\($0.lidCloseCount)회" }
        ),

        // MARK: Network
        MetricDefinition(
            id: "networkTotal",
            title: "네트워크 사용량",
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
            title: "다운로드",
            icon: "arrow.down.circle",
            explanation: "네트워크로 내려받은 총 바이트 수예요.",
            category: .powerPeripherals,
            value: { Double($0.networkDownloadBytes) },
            display: { Formatters.bytes($0.networkDownloadBytes) },
            lifetimeValue: { Double($0.networkDownloadBytes) },
            lifetimeDisplay: { Formatters.bytes($0.networkDownloadBytes) }
        ),
        MetricDefinition(
            id: "networkUpload",
            title: "업로드",
            icon: "arrow.up.circle",
            explanation: "네트워크로 올린 총 바이트 수예요.",
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
