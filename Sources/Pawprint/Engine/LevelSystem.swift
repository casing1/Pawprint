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
        case .keys: return L10n.t("levelSystem.a8053bb2")
        case .clicks: return L10n.t("levelSystem.6e3b1fc9")
        case .cursor: return L10n.t("levelSystem.1547ff52")
        case .scroll: return L10n.t("levelSystem.ebd0a3f2")
        case .focus: return L10n.t("levelSystem.56fb8019")
        case .screenTime: return L10n.t("levelSystem.613e4fe2")
        case .appSwitches: return L10n.t("levelSystem.359d66ba")
        case .clipboard: return L10n.t("levelSystem.06d761f3")
        case .shortcuts: return L10n.t("levelSystem.ba856e2a")
        case .days: return L10n.t("levelSystem.ef3f476b")
        case .energy: return L10n.t("levelSystem.b98bd486")
        }
    }

    /// Shown in the info popover so each track's meaning is explicit.
    var explanation: String {
        switch self {
        case .keys: return L10n.t("levelSystem.b9c971e7")
        case .clicks: return L10n.t("levelSystem.5f299b8f")
        case .cursor: return L10n.t("levelSystem.44cb5b77")
        case .scroll: return L10n.t("levelSystem.dbac1d26")
        case .focus: return L10n.t("levelSystem.af3b179d")
        case .screenTime: return L10n.t("levelSystem.b202cb01")
        case .appSwitches: return L10n.t("levelSystem.e81db37e")
        case .clipboard: return L10n.t("levelSystem.dbd85c85")
        case .shortcuts: return L10n.t("levelSystem.95684ce0")
        case .days: return L10n.t("levelSystem.7fa718d6")
        case .energy: return L10n.t("levelSystem.fd4c2fd0")
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

    /// Value with its unit, written the way the loaded language writes it.
    ///
    /// Each unit is a full template rather than a bare word glued onto the number. Korean attaches
    /// its units ("32,406회") and English does not ("32,406 times"), and concatenating in code
    /// could only be right for one of them — it printed "32,406times" and "322KClicking".
    func formatted(_ value: Double) -> String {
        let number = Formatters.compactNumber(Int(value.rounded()))
        switch self {
        case .focus, .screenTime:
            return Formatters.hoursValue(value)
        case .cursor:
            return Formatters.compactDistance(meters: value)
        case .energy:
            return value >= 1000
                ? String(format: "%.1fkWh", value / 1000)
                : String(format: "%.0fWh", value)
        case .keys: return L10n.t("levelSystem.a7c3c02f", number)
        case .clicks: return L10n.t("levelSystem.8dc0c89d", number)
        case .scroll: return L10n.t("levelSystem.5d3b8ef3", number)
        case .appSwitches, .clipboard, .shortcuts: return L10n.t("levelSystem.cf3d71b3", number)
        case .days: return L10n.t("levelSystem.cec3694e", number)
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
    static var ranks: [(upTo: Int, name: String)] { [
        (1, L10n.t("levelSystem.7f536d0d")), (2, L10n.t("levelSystem.c178a70d")), (3, L10n.t("levelSystem.806e4e54")), (4, L10n.t("levelSystem.e2adc854")),
        (5, L10n.t("levelSystem.b69efb2a")), (6, L10n.t("levelSystem.44bd2ea1")), (7, L10n.t("levelSystem.dc306dbb")), (8, L10n.t("levelSystem.25c2859f")),
        (9, L10n.t("levelSystem.97836f1c")), (10, L10n.t("levelSystem.881454cf")), (11, L10n.t("levelSystem.5f6cf8e4")), (12, L10n.t("levelSystem.433762c7")),
        (14, L10n.t("levelSystem.a3255cc7")), (16, L10n.t("levelSystem.72041dd0")), (19, L10n.t("levelSystem.46ab9b66")), (24, L10n.t("levelSystem.4e790ceb"))
    ] }

    static var rankCount: Int { ranks.count }

    /// Named rank for the current level. Beyond the last named rank the level number carries on
    /// alone — an infinite track shouldn't run out of things to call you, but inventing ever more
    /// grandiose words past "초월자" stops meaning anything.
    var tierName: String {
        guard level > 0 else { return L10n.t("levelSystem.bcfe1cbb") }
        for rank in Self.ranks where level <= rank.upTo { return rank.name }
        return L10n.t("levelSystem.4e790ceb")
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
    static var titles: [(upTo: Int, name: String)] { [
        (2, L10n.t("levelSystem.e10505c5")),
        (4, L10n.t("levelSystem.3bbe0f93")),
        (6, L10n.t("levelSystem.535a38ab")),
        (8, L10n.t("levelSystem.5ee8a80c")),
        (10, L10n.t("levelSystem.d7ba9586")),
        (12, L10n.t("levelSystem.21e46cf5")),
        (15, L10n.t("levelSystem.d1c8ac63")),
        (18, L10n.t("levelSystem.0cef9292")),
        (21, L10n.t("levelSystem.5eb1044a")),
        (25, L10n.t("levelSystem.1cb92e61")),
        (29, L10n.t("levelSystem.df4abe86")),
        (34, L10n.t("levelSystem.a8717cba")),
        (39, L10n.t("levelSystem.13f62bf5"))
    ] }

    private static func titleFor(_ level: Int) -> String {
        for entry in titles where level <= entry.upTo { return entry.name }
        return L10n.t("levelSystem.a3df0773")
    }
}
