import Foundation

/// A never-ending progression track. Each track measures one lifetime total and defines
/// thresholds that keep growing, so there's always a next level rather than a checklist that
/// runs out. Tiers are named, and beyond the named tiers the levels simply keep counting.
enum QuestTrack: String, CaseIterable, Identifiable {
    case keys
    case clicks
    case cursor
    case scroll
    case focus
    case screenTime
    case appSwitches
    case clipboard
    case shortcuts
    case days
    case energy

    var id: String { rawValue }

    /// Tracks measured in whole units (days, keystrokes, clicks). Their thresholds are snapped to
    /// integers — a target of 2.5 days would otherwise display as "2일" while actually requiring 3.
    var usesWholeUnits: Bool {
        switch self {
        case .focus, .screenTime, .cursor, .energy: return false
        case .keys, .clicks, .scroll, .appSwitches, .clipboard, .shortcuts, .days: return true
        }
    }

    /// The activity itself, as a bare noun.
    ///
    /// These used to be complete titles ("타건왕", "스크롤 등반가") with the rank stuck on the
    /// front, which produced "전문가 스크롤 등반가" — two role nouns fighting each other. A rank
    /// only reads naturally as a *suffix* in Korean, so the track names the activity and
    /// `QuestProgress.displayTitle` appends the rank: "스크롤 등반 전문가".
    var title: String {
        switch self {
        case .keys: return "타건"
        case .clicks: return "클릭"
        case .cursor: return "커서 질주"
        case .scroll: return "스크롤 등반"
        case .focus: return "집중"
        case .screenTime: return "화면 지킴"
        case .appSwitches: return "앱 전환"
        case .clipboard: return "복붙"
        case .shortcuts: return "단축키"
        case .days: return "개근"
        case .energy: return "전력 소비"
        }
    }

    /// Shown in the info popover so each track's meaning is explicit.
    var explanation: String {
        switch self {
        case .keys: return "지금까지 누른 모든 키의 합계예요. 어떤 키를 눌렀는지는 저장하지 않고 횟수만 셉니다."
        case .clicks: return "좌클릭·우클릭·더블클릭을 모두 더한 누적 클릭 수예요."
        case .cursor: return "커서가 화면 위를 움직인 총 거리를 이 Mac 화면의 실제 물리 크기 기준으로 환산했어요."
        case .scroll: return "스크롤한 양을 화면 높이 단위로 환산한 누적값이에요."
        case .focus: return "한 앱에서 방해 없이 이어서 작업한 시간의 누적 합계예요."
        case .screenTime: return "화면이 실제로 켜져 있던 시간의 누적 합계예요 (잠금·절전 시간은 제외)."
        case .appSwitches: return "다른 앱으로 전환한 횟수의 누적 합계예요."
        case .clipboard: return "복사와 붙여넣기 횟수의 합계예요. 클립보드 내용은 저장하지 않습니다."
        case .shortcuts: return "복사·붙여넣기·실행취소 등 OS 전역 단축키를 누른 누적 횟수예요."
        case .days: return "활동이 기록된 날의 수예요. 연속일이 아니라 총 일수라서 쉬어도 줄지 않아요."
        case .energy: return "배터리로 사용한 전력을 이 Mac 배터리의 실제 용량 기준으로 Wh 환산한 누적값이에요."
        }
    }

    var icon: String {
        switch self {
        case .keys: return "keyboard.fill"
        case .clicks: return "cursorarrow.click.2"
        case .cursor: return "figure.run"
        case .scroll: return "building.2.fill"
        case .focus: return "target"
        case .screenTime: return "display"
        case .appSwitches: return "arrow.left.arrow.right"
        case .clipboard: return "doc.on.clipboard.fill"
        case .shortcuts: return "command"
        case .days: return "flame.fill"
        case .energy: return "bolt.fill"
        }
    }

    var emoji: String {
        switch self {
        case .keys: return "⌨️"
        case .clicks: return "🖱️"
        case .cursor: return "🏃"
        case .scroll: return "🏢"
        case .focus: return "🎯"
        case .screenTime: return "🖥️"
        case .appSwitches: return "🐇"
        case .clipboard: return "📋"
        case .shortcuts: return "⚡️"
        case .days: return "🔥"
        case .energy: return "⚡️"
        }
    }

    var unit: String {
        switch self {
        case .keys: return "키"
        case .clicks: return "클릭"
        case .cursor: return "m"
        case .scroll: return "화면"
        case .focus: return "시간"
        case .screenTime: return "시간"
        case .appSwitches: return "회"
        case .clipboard: return "회"
        case .shortcuts: return "회"
        case .days: return "일"
        case .energy: return "Wh"
        }
    }

    /// Level 1's threshold. Later levels multiply this by `growth` repeatedly.
    var baseThreshold: Double {
        switch self {
        case .keys: return 300
        case .clicks: return 150
        case .cursor: return 30
        case .scroll: return 15
        case .focus: return 0.25       // hours
        case .screenTime: return 0.5   // hours
        case .appSwitches: return 40
        case .clipboard: return 10
        case .shortcuts: return 15
        case .days: return 1
        case .energy: return 5
        }
    }

    /// Per-level multiplier. Chosen so early levels come quickly and later ones feel earned,
    /// without ever becoming unreachable.
    var growth: Double {
        switch self {
        case .days: return 1.8
        case .focus, .screenTime, .energy: return 1.9
        default: return 2.15
        }
    }

    func currentValue(from stats: LifetimeStats) -> Double {
        switch self {
        case .keys: return Double(stats.totalKeyPresses)
        case .clicks: return Double(stats.totalClicks)
        case .cursor: return stats.cursorDistanceMeters
        case .scroll: return stats.scrollScreens
        case .focus: return Double(stats.totalFocusSeconds) / 3600
        case .screenTime: return Double(stats.totalScreenOnSeconds) / 3600
        case .appSwitches: return Double(stats.totalAppSwitches)
        case .clipboard: return Double(stats.clipboardCopyCount + stats.clipboardPasteCount)
        case .shortcuts: return Double(stats.shortcutTotal)
        case .days: return Double(stats.daysRecorded)
        case .energy: return stats.totalEnergyWattHours ?? 0
        }
    }

    static let maxLevel = 40

    /// Precomputed threshold ladder per track.
    ///
    /// Snapping raw geometric thresholds to friendly numbers (1 / 2 / 2.5 / 5 × a power of ten)
    /// can map two consecutive levels onto the *same* value at the slower growth rates — which
    /// would create a level that requires no additional progress and is skipped instantly. Each
    /// entry is therefore forced strictly above its predecessor.
    private static let thresholdTables: [QuestTrack: [Double]] = {
        var tables: [QuestTrack: [Double]] = [:]
        for track in QuestTrack.allCases {
            var values: [Double] = []
            var previous: Double = 0
            for level in 1...maxLevel {
                let raw = track.baseThreshold * pow(track.growth, Double(level - 1))
                var snapped = QuestProgress.roundedNicely(raw)
                if track.usesWholeUnits { snapped = max(1, snapped.rounded()) }
                if snapped <= previous {
                    snapped = QuestProgress.nextNiceValue(above: previous, wholeUnits: track.usesWholeUnits)
                }
                values.append(snapped)
                previous = snapped
            }
            tables[track] = values
        }
        return tables
    }()

    /// Threshold to *complete* the given level (1-based).
    func threshold(forLevel level: Int) -> Double {
        guard level >= 1 else { return 0 }
        guard let table = Self.thresholdTables[self], !table.isEmpty else { return baseThreshold }
        return table[min(level, table.count) - 1]
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .focus, .screenTime:
            return Formatters.hoursValue(value)
        case .cursor:
            return Formatters.compactDistance(meters: value)
        case .scroll:
            return Formatters.compactNumber(Int(value.rounded())) + "화면"
        case .energy:
            return value >= 1000
                ? String(format: "%.1fkWh", value / 1000)
                : String(format: "%.0fWh", value)
        default:
            return Formatters.compactNumber(Int(value.rounded())) + unit
        }
    }
}

struct QuestProgress: Identifiable {
    var track: QuestTrack
    var level: Int
    var currentValue: Double
    var levelStart: Double
    var levelTarget: Double

    var id: String { track.rawValue }

    /// 0...1 progress through the current level.
    var fraction: Double {
        let span = levelTarget - levelStart
        guard span > 0 else { return 0 }
        return min(1, max(0, (currentValue - levelStart) / span))
    }

    var remaining: Double { max(0, levelTarget - currentValue) }

    /// Ranks, in order. Each is a noun that can follow an activity name without a particle:
    /// "복붙 달인", "개근 명인". Levels 1–12 each get their own rank so every single level-up
    /// renames the title; past that they widen, because the climb slows down too.
    ///
    /// Kept as a table rather than a switch so adding a rank is a one-line change and
    /// `rankCount` stays correct on its own.
    static let ranks: [(upTo: Int, name: String)] = [
        (1, "입문자"), (2, "견습생"), (3, "수련생"), (4, "숙련자"),
        (5, "상급자"), (6, "전문가"), (7, "장인"), (8, "달인"),
        (9, "명인"), (10, "대가"), (11, "마스터"), (12, "그랜드마스터"),
        (14, "현자"), (16, "전설"), (19, "신화"), (24, "초월자")
    ]

    static var rankCount: Int { ranks.count }

    /// Named rank for the current level. Beyond the last named rank the level number carries on
    /// alone — an infinite track shouldn't run out of things to call you, but inventing ever more
    /// grandiose words past "초월자" stops meaning anything.
    var tierName: String {
        guard level > 0 else { return "시작 전" }
        for rank in Self.ranks where level <= rank.upTo { return rank.name }
        return "초월자"
    }

    /// "스크롤 등반 전문가" — activity first, rank last.
    var displayTitle: String {
        level == 0 ? track.title : "\(track.title) \(tierName)"
    }

    static func build(track: QuestTrack, stats: LifetimeStats) -> QuestProgress {
        let value = track.currentValue(from: stats)
        var level = 0
        // Levels are unbounded in principle; the cap only guards against a pathological loop.
        while level < 40 && value >= track.threshold(forLevel: level + 1) {
            level += 1
        }
        return QuestProgress(
            track: track,
            level: level,
            currentValue: value,
            levelStart: level == 0 ? 0 : track.threshold(forLevel: level),
            levelTarget: track.threshold(forLevel: level + 1)
        )
    }

    /// Rounds a raw threshold to a human-friendly number (1, 2, 2.5, 5 × a power of ten) so
    /// goals read like "50,000키" instead of "48,371키".
    static func roundedNicely(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude
        let snapped: Double
        switch normalized {
        case ..<1.5: snapped = 1
        case ..<2.25: snapped = 2
        case ..<3.5: snapped = 2.5
        case ..<7.5: snapped = 5
        default: snapped = 10
        }
        return snapped * magnitude
    }

    /// Next value on the 1 / 2 / 2.5 / 5 × 10ⁿ ladder strictly above `value`. Used to break ties
    /// when two consecutive raw thresholds snap to the same friendly number.
    static func nextNiceValue(above value: Double, wholeUnits: Bool) -> Double {
        guard value > 0 else { return wholeUnits ? 1 : 0.1 }
        let ladder: [Double] = [1, 2, 2.5, 5]
        var magnitude = pow(10, floor(log10(value)))
        // Walk upward through the ladder until something exceeds `value`.
        for _ in 0..<4 {
            for step in ladder {
                let candidate = step * magnitude
                let normalized = wholeUnits ? max(1, candidate.rounded()) : candidate
                if normalized > value { return normalized }
            }
            magnitude *= 10
        }
        return wholeUnits ? (value + 1).rounded() : value * 2
    }
}

/// Aggregates every track into an overall "Pawprint 레벨" so there's one headline number that
/// only ever goes up.
struct OverallLevel {
    var level: Int
    var title: String
    var totalLevels: Int

    static func build(from quests: [QuestProgress]) -> OverallLevel {
        let sum = quests.reduce(0) { $0 + $1.level }
        // Overall level rises roughly as the square root of accumulated track levels, so it
        // moves steadily without racing ahead of the individual tracks.
        let level = max(1, Int(Double(sum).squareRoot() * 1.6))
        return OverallLevel(level: level, title: titleFor(level), totalLevels: sum)
    }

    /// Headline titles, coarsest-to-finest. Unlike the per-track ranks these are whole phrases,
    /// since nothing gets appended to them.
    static let titles: [(upTo: Int, name: String)] = [
        (2, "갓 태어난 발자국"),
        (4, "아장아장 탐험가"),
        (6, "호기심 많은 발자국"),
        (8, "손에 익은 탐험가"),
        (10, "익숙한 사용자"),
        (12, "노련한 사용자"),
        (15, "베테랑"),
        (18, "Mac 마스터"),
        (21, "키보드의 지배자"),
        (25, "화면 너머의 현자"),
        (29, "발자국의 대가"),
        (34, "전설의 발자국"),
        (39, "신화가 된 발자국")
    ]

    private static func titleFor(_ level: Int) -> String {
        for entry in titles where level <= entry.upTo { return entry.name }
        return "발자국 그 자체"
    }
}
