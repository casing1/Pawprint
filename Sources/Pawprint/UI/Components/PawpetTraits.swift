import SwiftUI

/// Every visual axis of the day's cat, plus the reason each one looks the way it does.
///
/// The axes are split in two on purpose:
///
///  * **Identity** — palette, pattern, ears, tail, eye colour, whiskers, cheek fluff. Seeded from
///    the *date string alone*, so the cat stays the same animal from midnight to midnight. An
///    earlier version mixed live counters into the seed, which made the drawing mutate on every
///    keystroke — distracting rather than fun.
///  * **State** — expression, headwear, eyewear, prop, collar, cheek marks, aura, floaters. Every
///    state axis is driven by a *different* metric, so the cat reads as a summary of the whole day
///    instead of one number restyled eight ways. Two heavy-typing days with different break
///    patterns, error rates and schedules produce visibly different cats.
///
/// Because the axes are independent, the number of reachable cats is the product of their case
/// counts — see `combinationCount`, which is derived from the enums rather than written down, so
/// adding a case updates the figure automatically.
struct PawpetTraits {

    // MARK: - Identity axes (date-seeded)

    enum EarShape: Int, CaseIterable { case pointed, round, tufted, folded, curled }
    enum Pattern: Int, CaseIterable { case plain, tabby, spotted, tuxedo, calico, colorpoint, bicolor, star }
    enum TailShape: Int, CaseIterable { case curved, upright, curled, bushy }
    enum CheekFluff: Int, CaseIterable { case none, light, full }

    // MARK: - State axes (metric-driven)

    enum Expression: CaseIterable {
        case content, sleepy, dizzy, chaotic, surprised, determined
        case focused, mischief, tired, zen, wide, sparkle
    }
    enum Headwear: CaseIterable {
        case none, crown, partyHat, halo, headphones, nightcap, beanie, bandana
    }
    enum Eyewear: CaseIterable { case none, readingGlasses, sunglasses }
    enum Prop: CaseIterable { case none, coffee, mouse, plug, yarn, moon, book, fish }
    enum Collar: Int, CaseIterable { case none, cloth, blue, green, gold, rainbow }
    enum CheekMark: CaseIterable { case none, blush, sweat, flushed }
    enum Aura: CaseIterable { case dawn, morning, afternoon, evening, night, deepNight }
    enum Floaters: CaseIterable { case none, zzz, sparkles, notes, bits }

    // MARK: - Reward axes
    //
    // These are the ones you *earn*. Unlike the state axes above — which describe the day
    // neutrally — a charm, a frame or a pair of wings only shows up once a threshold is crossed,
    // so seeing one means something happened. Which charm you get is date-random, so two heavy
    // typing days don't produce the same picture.

    /// A large glowing object at the cat's paw. Unlocked by heavy typing; the specific one is
    /// drawn from the date, so it's a small surprise rather than a fixed badge.
    enum PawCharm: Int, CaseIterable { case none, orb, gauntlet, star, ring, flame, crystal, feather }

    /// Border around the whole portrait, earned by the day's grade.
    enum Frame: Int, CaseIterable { case none, bronze, silver, gold, prismatic }

    /// Earned by covering distance — scrolling or moving the cursor a very long way.
    enum Wings: Int, CaseIterable { case none, feathered, crystal, ember }

    /// Something happening behind the cat on a standout day.
    enum Backdrop: Int, CaseIterable { case none, rays, orbit, constellation }

    /// Total reachable looks, computed from the axes themselves so it can never drift out of date.
    ///
    /// This is the raw product of independent axes. A handful of pairs correlate in practice (a
    /// celebrating cat always wears the party hat), so not every single combination is reachable
    /// on a real day — but the order of magnitude is honest.
    static var combinationCount: Int {
        let identity = palettes.count
            * Pattern.allCases.count
            * EarShape.allCases.count
            * whiskerChoices.count
            * eyeColors.count
            * TailShape.allCases.count
            * CheekFluff.allCases.count
        let state = Expression.allCases.count
            * Headwear.allCases.count
            * Eyewear.allCases.count
            * Prop.allCases.count
            * Collar.allCases.count
            * CheekMark.allCases.count
            * Aura.allCases.count
            * Floaters.allCases.count
        let rewards = PawCharm.allCases.count
            * Frame.allCases.count
            * Wings.allCases.count
            * Backdrop.allCases.count
        return identity * state * rewards
    }

    // MARK: - Palettes

    /// Fur palettes, chosen to stay readable against both light and dark popover backgrounds.
    static let palettes: [(nameKey: String, body: Color, accent: Color)] = [
        ("pawpetTraits.7d880b36", Color(red: 0.98, green: 0.76, blue: 0.42), Color(red: 0.86, green: 0.55, blue: 0.22)),
        ("pawpetTraits.95aff2e2", Color(red: 0.65, green: 0.70, blue: 0.80), Color(red: 0.42, green: 0.47, blue: 0.60)),
        ("pawpetTraits.4edf416c", Color(red: 0.38, green: 0.36, blue: 0.44), Color(red: 0.24, green: 0.22, blue: 0.30)),
        ("pawpetTraits.5ee50d64", Color(red: 0.96, green: 0.93, blue: 0.87), Color(red: 0.80, green: 0.74, blue: 0.66)),
        ("pawpetTraits.1e1a1de3", Color(red: 0.72, green: 0.58, blue: 0.88), Color(red: 0.55, green: 0.42, blue: 0.72)),
        ("pawpetTraits.325c68c5", Color(red: 0.52, green: 0.78, blue: 0.72), Color(red: 0.32, green: 0.58, blue: 0.54)),
        ("pawpetTraits.adf31fb3", Color(red: 0.95, green: 0.66, blue: 0.62), Color(red: 0.80, green: 0.46, blue: 0.44)),
        ("pawpetTraits.b2efa911", Color(red: 0.78, green: 0.56, blue: 0.36), Color(red: 0.56, green: 0.38, blue: 0.22)),
        ("pawpetTraits.6ef10536", Color(red: 0.55, green: 0.56, blue: 0.62), Color(red: 0.36, green: 0.37, blue: 0.43)),
        ("pawpetTraits.c3d78839", Color(red: 0.60, green: 0.76, blue: 0.92), Color(red: 0.38, green: 0.56, blue: 0.76)),
        ("pawpetTraits.9186d609", Color(red: 0.72, green: 0.76, blue: 0.52), Color(red: 0.50, green: 0.55, blue: 0.32)),
        ("pawpetTraits.dec12dfa", Color(red: 0.90, green: 0.58, blue: 0.70), Color(red: 0.72, green: 0.38, blue: 0.52)),
        ("pawpetTraits.a601624f", Color(red: 0.90, green: 0.82, blue: 0.66), Color(red: 0.70, green: 0.60, blue: 0.44)),
        ("pawpetTraits.a68347a4", Color(red: 0.48, green: 0.54, blue: 0.86), Color(red: 0.32, green: 0.36, blue: 0.66)),
    ]

    /// Iris colours. Real cats have a narrow range; these stretch it a little for variety.
    static let eyeColors: [(nameKey: String, color: Color)] = [
        ("pawpetTraits.f68d8bf7", Color(red: 0.95, green: 0.70, blue: 0.20)),
        ("pawpetTraits.52c235b4", Color(red: 0.24, green: 0.72, blue: 0.48)),
        ("pawpetTraits.07b29498", Color(red: 0.30, green: 0.52, blue: 0.92)),
        ("pawpetTraits.7f43f859", Color(red: 0.82, green: 0.45, blue: 0.18)),
        ("pawpetTraits.cf5632c7", Color(red: 0.98, green: 0.84, blue: 0.36)),
        ("pawpetTraits.4829c30d", Color(red: 0.62, green: 0.82, blue: 0.36)),
        ("pawpetTraits.f4559417", Color(red: 0.62, green: 0.66, blue: 0.72)),
        ("pawpetTraits.917f54a7", Color(red: 0.68, green: 0.44, blue: 0.86)),
    ]

    /// Resolved on read, so switching language renames the coats too.
    static func paletteName(_ index: Int) -> String { L10n.t(palettes[index].nameKey) }
    static func eyeColorName(_ index: Int) -> String { L10n.t(eyeColors[index].nameKey) }

    static let whiskerChoices = [2, 3, 4]

    // MARK: - Resolved values

    var paletteIndex: Int
    var eyeColorIndex: Int
    var ears: EarShape
    var pattern: Pattern
    var tail: TailShape
    var cheekFluff: CheekFluff
    var whiskers: Int

    var expression: Expression
    var headwear: Headwear
    var eyewear: Eyewear
    var prop: Prop
    var collar: Collar
    var cheekMark: CheekMark
    var aura: Aura
    var floaters: Floaters

    var pawCharm: PawCharm
    var frame: Frame
    var wings: Wings
    var backdrop: Backdrop

    /// Convenience for matching both date-drawn reward traits at once.
    var charmAndWings: (PawCharm, Wings) { (pawCharm, wings) }

    /// Set when anything on a reward axis is showing, so the UI can call the day out.
    var hasReward: Bool {
        pawCharm != .none || frame != .none || wings != .none || backdrop != .none
    }

    var bodyColor: Color { Self.palettes[paletteIndex].body }
    var accentColor: Color { Self.palettes[paletteIndex].accent }
    var irisColor: Color { Self.eyeColors[eyeColorIndex].color }

    // MARK: - Derivation

    /// `setARecord` is a fact about the day, read from `AppSettings.recordDays`. It used to be
    /// `isCelebrating` — literally "is the congratulation banner on screen" — which meant the cat
    /// changed when you dismissed a banner, and reverted on relaunch.
    init(day: String, summary: DailySummary, streakDays: Int = 0, setARecord: Bool = false) {
        // --- Identity: date only ---
        var generator = SeededGenerator(seed: Self.daySeed(day))
        paletteIndex = generator.nextInt(below: Self.palettes.count)
        pattern = Pattern(rawValue: generator.nextInt(below: Pattern.allCases.count)) ?? .plain
        ears = EarShape(rawValue: generator.nextInt(below: EarShape.allCases.count)) ?? .pointed
        whiskers = Self.whiskerChoices[generator.nextInt(below: Self.whiskerChoices.count)]
        eyeColorIndex = generator.nextInt(below: Self.eyeColors.count)
        tail = TailShape(rawValue: generator.nextInt(below: TailShape.allCases.count)) ?? .curved
        cheekFluff = CheekFluff(rawValue: generator.nextInt(below: CheekFluff.allCases.count)) ?? .none

        // --- State: one metric per axis ---
        let score = summary.score?.total ?? 0

        expression = Self.expression(summary, score: score)
        headwear = Self.headwear(summary, score: score, setARecord: setARecord)
        eyewear = Self.eyewear(summary)
        prop = Self.prop(summary)
        collar = Self.collar(streakDays: streakDays)
        cheekMark = Self.cheekMark(summary, score: score)
        aura = Self.aura(summary)
        floaters = Self.floaters(summary, setARecord: setARecord)

        // Rewards. `generator` has already been advanced by the identity draws, so the charm and
        // wing choices vary from day to day without needing a second seed.
        pawCharm = Self.pawCharm(summary, generator: &generator)
        frame = Self.frame(score: score)
        wings = Self.wings(summary, generator: &generator)
        backdrop = Self.backdrop(summary, score: score)
    }

    /// A stable hash of the date string. `String.hashValue` is salted per process and would hand
    /// out a different cat on every launch.
    static func daySeed(_ day: String) -> UInt64 {
        var value: UInt64 = 0xCBF29CE484222325
        for byte in day.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x100000001B3
        }
        return value
    }

    // Each of these is a priority chain over one metric family. Thresholds are coarse so the cat
    // changes a handful of times a day rather than continuously.

    private static func expression(_ s: DailySummary, score: Int) -> Expression {
        // Sparkle used to mean "a record banner is on screen", which made it disappear the moment
        // the banner was dismissed. It now belongs to the very best days — a rung above the crown
        // at 85, so it stays the rarest face rather than becoming a second way to say "grade S".
        if score >= 90 { return .sparkle }
        if s.activeSeconds < 300 { return .sleepy }
        if s.totalKeyPresses > 50, s.backspaceRatio > 0.30 { return .dizzy }
        if s.chaosIndex >= 70 { return .chaotic }
        if s.maxClicksPerMinute >= 60 { return .surprised }
        if s.maxWPM >= 100 { return .determined }
        if s.longestFocusSeconds >= 45 * 60 { return .focused }
        if s.totalAppSwitches >= 200 { return .mischief }
        if s.screenOnSeconds >= 4 * 3600, s.screenUtilizationPercent < 35 { return .tired }
        if s.longestBreakSeconds >= 2 * 3600 { return .zen }
        if score >= 75 { return .wide }
        return .content
    }

    private static func headwear(_ s: DailySummary, score: Int, setARecord: Bool) -> Headwear {
        if setARecord { return .partyHat }
        if score >= 85 { return .crown }
        if s.totalKeyPresses >= 500, s.regretIndex <= 15 { return .halo }
        if s.audioOutputDeviceChangeCount >= 2 { return .headphones }
        if let last = s.lastActivity, Calendar.current.component(.hour, from: last) < 5 { return .nightcap }
        if s.lidOpenCount >= 3 { return .beanie }
        if s.distinctShortcutsUsed >= 10 { return .bandana }
        return .none
    }

    private static func eyewear(_ s: DailySummary) -> Eyewear {
        if s.screenOnSeconds >= 8 * 3600 { return .sunglasses }
        if s.characterKeyPresses >= 8_000 { return .readingGlasses }
        return .none
    }

    private static func prop(_ s: DailySummary) -> Prop {
        if let last = s.lastActivity, (0..<5).contains(Calendar.current.component(.hour, from: last)) { return .moon }
        if let first = s.firstActivity, Calendar.current.component(.hour, from: first) < 8 { return .coffee }
        if s.characterKeyPresses >= 20_000 { return .book }
        if s.totalClicks >= 2_000 { return .mouse }
        if s.scrollDirectionChanges >= 300 { return .yarn }
        if s.secondsOnAC > 3_600, s.secondsOnAC >= s.secondsOnBattery * 3 { return .plug }
        if s.totalSleepSeconds >= 2 * 3600 { return .fish }
        return .none
    }

    private static func collar(streakDays: Int) -> Collar {
        switch streakDays {
        case ..<1: return .none
        case 1...2: return .cloth
        case 3...6: return .blue
        case 7...13: return .green
        case 14...29: return .gold
        default: return .rainbow
        }
    }

    private static func cheekMark(_ s: DailySummary, score: Int) -> CheekMark {
        if s.elevatedThermalSeconds > 0 { return .flushed }
        if s.maxWPM >= 120 { return .sweat }
        if score >= 60 { return .blush }
        return .none
    }

    private static func aura(_ s: DailySummary) -> Aura {
        // Whichever hour the day actually peaked in, falling back to when it started.
        let hour = s.goldenHour
            ?? s.busiestMinute.map { $0 / 60 }
            ?? s.firstActivity.map { Calendar.current.component(.hour, from: $0) }
            ?? 12
        switch hour {
        case 0..<5: return .deepNight
        case 5..<8: return .dawn
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    private static func floaters(_ s: DailySummary, setARecord: Bool) -> Floaters {
        if setARecord { return .sparkles }
        if s.idleSeconds > 3_600, s.idleSeconds > s.activeSeconds * 2 { return .zzz }
        if s.networkTotalBytes >= 5 * 1024 * 1024 * 1024 { return .bits }
        if s.audioOutputDeviceChangeCount >= 3 { return .notes }
        return .none
    }

    /// Typing unlocks the paw charm. 4,000 keys is a solidly heavy day — roughly an hour of
    /// sustained writing — so it stays an event rather than a permanent fixture.
    private static func pawCharm(_ s: DailySummary, generator: inout SeededGenerator) -> PawCharm {
        guard s.totalKeyPresses >= 4_000 else { return .none }
        let choices = PawCharm.allCases.filter { $0 != .none }
        return choices[generator.nextInt(below: choices.count)]
    }

    /// Score alone. A broken record used to force the prismatic frame, which is 32 of the 100
    /// rarity points on its own — enough to lift any day, however quiet, straight to grade S.
    /// Setting a personal best is now worth the party hat and the sparkles (8 points together);
    /// the frame stays an honest reading of the day's score.
    private static func frame(score: Int) -> Frame {
        // Mirrors `PawprintScore.gradeFor`: S / A / B / C.
        switch score {
        case 85...: return .prismatic
        case 70..<85: return .gold
        case 50..<70: return .silver
        case 30..<50: return .bronze
        default: return .none
        }
    }

    private static func wings(_ s: DailySummary, generator: inout SeededGenerator) -> Wings {
        let earned = s.scrollScreens >= 400 || s.cursorDistanceMeters >= 700
        guard earned else { return .none }
        let choices = Wings.allCases.filter { $0 != .none }
        return choices[generator.nextInt(below: choices.count)]
    }

    private static func backdrop(_ s: DailySummary, score: Int) -> Backdrop {
        if score >= 80 { return .rays }
        if s.totalAppSwitches >= 150 { return .orbit }
        if let last = s.lastActivity, Calendar.current.component(.hour, from: last) < 5 { return .constellation }
        return .none
    }

    // MARK: - Rarity

    /// How rare this cat is, 0–100.
    ///
    /// The scale is built so that the maximum configuration lands on exactly 100: every reward
    /// axis at its top tier (80 points, the part you *earn*) plus every flourish (20 points).
    /// It is deliberately dominated by the reward axes — a cat is rare because the day was
    /// exceptional, not because the date happened to roll an unusual coat. Identity traits
    /// (colour, pattern, ears) contribute nothing: they're uniformly random, so scoring them
    /// would just add noise you can't influence.
    var rarity: Int {
        Int(rarityBreakdown.reduce(0) { $0 + $1.earned }.rounded())
    }

    /// Per-axis contribution, for the stat sheet. Ordered heaviest first.
    var rarityBreakdown: [(label: String, detail: String, earned: Double, maximum: Double)] {
        [
            (L10n.t("pawpetTraits.7ad40d7f"), frame == .none ? L10n.t("pawpetTraits.d58fa73a") : frameName, framePoints, 32),
            (L10n.t("pawpetTraits.e47d8fb5"), pawCharm == .none ? L10n.t("pawpetTraits.d58fa73a") : pawCharmName, pawCharm == .none ? 0 : 20, 20),
            (L10n.t("pawpetTraits.01a400a4"), wings == .none ? L10n.t("pawpetTraits.d58fa73a") : wingsName, wings == .none ? 0 : 16, 16),
            (L10n.t("pawpetTraits.5f74c72f"), backdropName, backdropPoints, 12),
            (L10n.t("pawpetTraits.5a60c868"), collar == .none ? L10n.t("pawpetTraits.d58fa73a") : collarName, collarPoints, 8),
            (L10n.t("pawpetTraits.75b9f271"), headwear == .none ? L10n.t("pawpetTraits.d58fa73a") : headwearName, headwearPoints, 6),
            (L10n.t("pawpetTraits.8fab9174"), caption, expressionPoints, 4),
            (L10n.t("pawpetTraits.b7c049aa"), floaters == .none ? L10n.t("pawpetTraits.d58fa73a") : floatersName, floaters == .none ? 0 : 2, 2)
        ]
    }

    static func framePoints(_ value: Frame) -> Double {
        switch value {
        case .none: return 0
        case .bronze: return 8
        case .silver: return 16
        case .gold: return 24
        case .prismatic: return 32
        }
    }

    private var framePoints: Double { Self.framePoints(frame) }

    static func backdropPoints(_ value: Backdrop) -> Double {
        switch value {
        case .none: return 0
        case .orbit: return 6
        case .constellation: return 8
        case .rays: return 12
        }
    }

    private var backdropPoints: Double { Self.backdropPoints(backdrop) }

    static func collarPoints(_ value: Collar) -> Double {
        switch value {
        case .none: return 0
        case .cloth: return 1
        case .blue: return 2
        case .green: return 3
        case .gold: return 5
        case .rainbow: return 8
        }
    }

    private var collarPoints: Double { Self.collarPoints(collar) }

    static func headwearPoints(_ value: Headwear) -> Double {
        switch value {
        case .none: return 0
        case .bandana, .beanie: return 2
        case .nightcap, .headphones: return 3
        case .halo: return 4
        case .crown: return 5
        case .partyHat: return 6
        }
    }

    private var headwearPoints: Double { Self.headwearPoints(headwear) }

    /// Expressions you only see on an unusual day score higher than the everyday ones.
    static func expressionPoints(_ value: Expression) -> Double {
        switch value {
        case .content: return 0
        case .wide, .sleepy: return 1
        case .tired, .zen, .mischief: return 2
        case .dizzy, .chaotic, .surprised, .focused: return 3
        case .determined, .sparkle: return 4
        }
    }

    private var expressionPoints: Double { Self.expressionPoints(expression) }

    /// S / A / B / C / D, matching how the day's score grades read elsewhere in the app.
    var rarityGrade: String {
        switch rarity {
        case 85...: return "S"
        case 70..<85: return "A"
        case 50..<70: return "B"
        case 30..<50: return "C"
        default: return "D"
        }
    }

    var rarityColor: Color {
        switch rarityGrade {
        case "S": return Color(red: 1.0, green: 0.72, blue: 0.20)
        case "A": return Color(red: 0.72, green: 0.48, blue: 0.98)
        case "B": return Color(red: 0.32, green: 0.62, blue: 0.95)
        case "C": return Color(red: 0.35, green: 0.72, blue: 0.52)
        default: return Color.secondary
        }
    }

    var rarityLabel: String {
        switch rarityGrade {
        case "S": return L10n.t("pawpetTraits.72041dd0")
        case "A": return L10n.t("pawpetTraits.40209554")
        case "B": return L10n.t("pawpetTraits.1c208809")
        case "C": return L10n.t("pawpetTraits.aef1a1e7")
        default: return L10n.t("pawpetTraits.da76a730")
        }
    }

    // MARK: - Trait names

    static func expressionName(_ value: Expression) -> String {
        switch value {
        case .content: return L10n.t("itemCatalog.expression.content")
        case .sleepy: return L10n.t("itemCatalog.expression.sleepy")
        case .dizzy: return L10n.t("itemCatalog.expression.dizzy")
        case .chaotic: return L10n.t("itemCatalog.expression.chaotic")
        case .surprised: return L10n.t("itemCatalog.expression.surprised")
        case .determined: return L10n.t("itemCatalog.expression.determined")
        case .focused: return L10n.t("itemCatalog.expression.focused")
        case .mischief: return L10n.t("itemCatalog.expression.mischief")
        case .tired: return L10n.t("itemCatalog.expression.tired")
        case .zen: return L10n.t("itemCatalog.expression.zen")
        case .wide: return L10n.t("itemCatalog.expression.wide")
        case .sparkle: return L10n.t("itemCatalog.expression.sparkle")
        }
    }

    static func auraName(_ value: Aura) -> String {
        switch value {
        case .dawn: return L10n.t("itemCatalog.aura.dawn")
        case .morning: return L10n.t("itemCatalog.aura.morning")
        case .afternoon: return L10n.t("itemCatalog.aura.afternoon")
        case .evening: return L10n.t("itemCatalog.aura.evening")
        case .night: return L10n.t("itemCatalog.aura.night")
        case .deepNight: return L10n.t("itemCatalog.aura.deepNight")
        }
    }

    static func cheekMarkName(_ value: CheekMark) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .blush: return L10n.t("itemCatalog.cheek.blush")
        case .sweat: return L10n.t("itemCatalog.cheek.sweat")
        case .flushed: return L10n.t("itemCatalog.cheek.flushed")
        }
    }

    static func wingsName(_ value: Wings) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .feathered: return L10n.t("pawpetTraits.e75e6f55")
        case .crystal: return L10n.t("pawpetTraits.18aa0a59")
        case .ember: return L10n.t("pawpetTraits.8fa35484")
        }
    }

    var wingsName: String { Self.wingsName(wings) }

    static func backdropName(_ value: Backdrop) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .rays: return L10n.t("pawpetTraits.d5b81e3a")
        case .orbit: return L10n.t("pawpetTraits.f7108d6b")
        case .constellation: return L10n.t("pawpetTraits.6d64da0b")
        }
    }

    var backdropName: String { Self.backdropName(backdrop) }

    static func collarName(_ value: Collar) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .cloth: return L10n.t("pawpetTraits.a449c92e")
        case .blue: return L10n.t("pawpetTraits.b3b21fe3")
        case .green: return L10n.t("pawpetTraits.6d2d78d1")
        case .gold: return L10n.t("pawpetTraits.b00df824")
        case .rainbow: return L10n.t("pawpetTraits.65de09fa")
        }
    }

    var collarName: String { Self.collarName(collar) }

    static func headwearName(_ value: Headwear) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .crown: return L10n.t("pawpetTraits.06b5d92a")
        case .partyHat: return L10n.t("pawpetTraits.792ef7d9")
        case .halo: return L10n.t("pawpetTraits.144438cc")
        case .headphones: return L10n.t("pawpetTraits.b9c8accf")
        case .nightcap: return L10n.t("pawpetTraits.c0c9fb47")
        case .beanie: return L10n.t("pawpetTraits.e742b4b6")
        case .bandana: return L10n.t("pawpetTraits.7f3dac0c")
        }
    }

    var headwearName: String { Self.headwearName(headwear) }

    static func floatersName(_ value: Floaters) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .zzz: return "zzz"
        case .sparkles: return L10n.t("pawpetTraits.298fcc03")
        case .notes: return L10n.t("pawpetTraits.ee8efc43")
        case .bits: return L10n.t("pawpetTraits.0c6de345")
        }
    }

    var floatersName: String { Self.floatersName(floaters) }

    static func eyewearName(_ value: Eyewear) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .readingGlasses: return L10n.t("pawpetTraits.36fd982f")
        case .sunglasses: return L10n.t("pawpetTraits.4ba1da9d")
        }
    }

    var eyewearName: String { Self.eyewearName(eyewear) }

    static func propName(_ value: Prop) -> String {
        switch value {
        case .none: return L10n.t("pawpetTraits.d58fa73a")
        case .coffee: return L10n.t("pawpetTraits.98bb79d2")
        case .mouse: return L10n.t("pawpetTraits.fcf9e282")
        case .plug: return L10n.t("pawpetTraits.b03617ef")
        case .yarn: return L10n.t("pawpetTraits.48bdfdbd")
        case .moon: return L10n.t("pawpetTraits.f743af38")
        case .book: return L10n.t("pawpetTraits.62cc8ca8")
        case .fish: return L10n.t("pawpetTraits.b6f5983b")
        }
    }

    var propName: String { Self.propName(prop) }

    // MARK: - Explanations

    /// One-line headline for the card.
    var caption: String {
        switch expression {
        case .sparkle: return L10n.t("pawpetTraits.d201772a")
        case .sleepy: return L10n.t("pawpetTraits.e8e833c8")
        case .dizzy: return L10n.t("pawpetTraits.9f44dbf5")
        case .chaotic: return L10n.t("pawpetTraits.b8c09a64")
        case .surprised: return L10n.t("pawpetTraits.e99859a4")
        case .determined: return L10n.t("pawpetTraits.c9aa57dc")
        case .focused: return L10n.t("pawpetTraits.e4846006")
        case .mischief: return L10n.t("pawpetTraits.514cc2e1")
        case .tired: return L10n.t("pawpetTraits.b25986ba")
        case .zen: return L10n.t("pawpetTraits.5abd0753")
        case .wide: return L10n.t("pawpetTraits.1e528f48")
        case .content: return L10n.t("pawpetTraits.d1d719fb")
        }
    }

    /// Why each visible trait looks the way it does. The cat is only interesting if you can read
    /// it, so the card lists the ones that are actually showing.
    var notes: [(trait: String, reason: String)] {
        var out: [(String, String)] = []
        out.append((L10n.t("pawpetTraits.8fab9174"), expressionReason))
        if headwear != .none { out.append((L10n.t("pawpetTraits.75b9f271"), headwearReason)) }
        if eyewear != .none { out.append((L10n.t("pawpetTraits.36fd982f"), eyewearReason)) }
        if prop != .none { out.append((L10n.t("pawpetTraits.6bf682a9"), propReason)) }
        if collar != .none { out.append((L10n.t("pawpetTraits.5a60c868"), collarReason)) }
        if cheekMark != .none { out.append((L10n.t("pawpetTraits.c72996aa"), cheekReason)) }
        if floaters != .none { out.append((L10n.t("pawpetTraits.b7c049aa"), floatersReason)) }
        if pawCharm != .none { out.append((L10n.t("pawpetTraits.5379d7a7"), pawCharmReason)) }
        if wings != .none { out.append((L10n.t("pawpetTraits.01a400a4"), wingsReason)) }
        if frame != .none { out.append((L10n.t("pawpetTraits.7ad40d7f"), frameReason)) }
        if backdrop != .none { out.append((L10n.t("pawpetTraits.5f74c72f"), backdropReason)) }
        out.append((L10n.t("pawpetTraits.a323dbfd"), auraReason))
        out.append((L10n.t("pawpetTraits.ac57252c"), L10n.t("pawpetTraits.6cfc18bd", Self.paletteName(paletteIndex), patternName, Self.eyeColorName(eyeColorIndex))))
        return out
    }

    var patternName: String {
        switch pattern {
        case .plain: return L10n.t("pawpetTraits.1889cf79")
        case .tabby: return L10n.t("pawpetTraits.09f376eb")
        case .spotted: return L10n.t("pawpetTraits.4d253937")
        case .tuxedo: return L10n.t("pawpetTraits.99ea289c")
        case .calico: return L10n.t("pawpetTraits.485a4b3c")
        case .colorpoint: return L10n.t("pawpetTraits.8a14132f")
        case .bicolor: return L10n.t("pawpetTraits.01b3c581")
        case .star: return L10n.t("pawpetTraits.db64710e")
        }
    }

    private var expressionReason: String {
        switch expression {
        case .sparkle: return L10n.t("pawpetTraits.2b14f345")
        case .sleepy: return L10n.t("pawpetTraits.b36dbd4d")
        case .dizzy: return L10n.t("pawpetTraits.4673129a")
        case .chaotic: return L10n.t("pawpetTraits.1f4479f3")
        case .surprised: return L10n.t("pawpetTraits.30f01847")
        case .determined: return L10n.t("pawpetTraits.a40bf47d")
        case .focused: return L10n.t("pawpetTraits.158ec44a")
        case .mischief: return L10n.t("pawpetTraits.012b1cc7")
        case .tired: return L10n.t("pawpetTraits.85b25476")
        case .zen: return L10n.t("pawpetTraits.1c843556")
        case .wide: return L10n.t("pawpetTraits.6220da3b")
        case .content: return L10n.t("pawpetTraits.34cadd3a")
        }
    }

    private var headwearReason: String {
        switch headwear {
        case .partyHat: return L10n.t("pawpetTraits.0bf3a54a")
        case .crown: return L10n.t("pawpetTraits.16653ea8")
        case .halo: return L10n.t("pawpetTraits.99ec6a4c")
        case .headphones: return L10n.t("pawpetTraits.af74af0b")
        case .nightcap: return L10n.t("pawpetTraits.6347ec06")
        case .beanie: return L10n.t("pawpetTraits.0ff6ba32")
        case .bandana: return L10n.t("pawpetTraits.c34a242b")
        case .none: return ""
        }
    }

    private var eyewearReason: String {
        switch eyewear {
        case .sunglasses: return L10n.t("pawpetTraits.e6dd91c0")
        case .readingGlasses: return L10n.t("pawpetTraits.0e3d5d79")
        case .none: return ""
        }
    }

    private var propReason: String {
        switch prop {
        case .moon: return L10n.t("pawpetTraits.48effde9")
        case .coffee: return L10n.t("pawpetTraits.62255bda")
        case .book: return L10n.t("pawpetTraits.1ee8d168")
        case .mouse: return L10n.t("pawpetTraits.6bb9ad8c")
        case .yarn: return L10n.t("pawpetTraits.c48f66d6")
        case .plug: return L10n.t("pawpetTraits.144bcb7a")
        case .fish: return L10n.t("pawpetTraits.2044942e")
        case .none: return ""
        }
    }

    private var collarReason: String {
        switch collar {
        case .cloth: return L10n.t("pawpetTraits.603207ea")
        case .blue: return L10n.t("pawpetTraits.212655bb")
        case .green: return L10n.t("pawpetTraits.6d324d14")
        case .gold: return L10n.t("pawpetTraits.099788bb")
        case .rainbow: return L10n.t("pawpetTraits.f66a34c9")
        case .none: return ""
        }
    }

    private var cheekReason: String {
        switch cheekMark {
        case .flushed: return L10n.t("pawpetTraits.066d5b9c")
        case .sweat: return L10n.t("pawpetTraits.1daae206")
        case .blush: return L10n.t("pawpetTraits.2bbfc2d9")
        case .none: return ""
        }
    }

    private var floatersReason: String {
        switch floaters {
        case .sparkles: return L10n.t("pawpetTraits.e202074d")
        case .zzz: return L10n.t("pawpetTraits.bcf6b1d0")
        case .bits: return L10n.t("pawpetTraits.128a9371")
        case .notes: return L10n.t("pawpetTraits.24214c16")
        case .none: return ""
        }
    }

    static func pawCharmName(_ value: PawCharm) -> String {
        switch value {
        case .none: return ""
        case .orb: return L10n.t("pawpetTraits.6e85059f")
        case .gauntlet: return L10n.t("pawpetTraits.3cbcba5c")
        case .star: return L10n.t("pawpetTraits.566093b1")
        case .ring: return L10n.t("pawpetTraits.8ab7ae6f")
        case .flame: return L10n.t("pawpetTraits.0e3c33f1")
        case .crystal: return L10n.t("pawpetTraits.c5fc25c2")
        case .feather: return L10n.t("pawpetTraits.99d5a5fb")
        }
    }

    var pawCharmName: String { Self.pawCharmName(pawCharm) }

    private var pawCharmReason: String {
        L10n.t("pawpetTraits.d9687f00", pawCharmName)
    }

    private var wingsReason: String {
        switch wings {
        case .feathered: return L10n.t("pawpetTraits.2111b0a4")
        case .crystal: return L10n.t("pawpetTraits.4d163bae")
        case .ember: return L10n.t("pawpetTraits.14813c31")
        case .none: return ""
        }
    }

    static func frameName(_ value: Frame) -> String {
        switch value {
        case .none: return ""
        case .bronze: return L10n.t("pawpetTraits.99dfaa5d")
        case .silver: return L10n.t("pawpetTraits.6cc903d4")
        case .gold: return L10n.t("pawpetTraits.3bc1d5a1")
        case .prismatic: return L10n.t("pawpetTraits.327fbaba")
        }
    }

    var frameName: String { Self.frameName(frame) }

    private var frameReason: String {
        switch frame {
        case .prismatic: return L10n.t("pawpetTraits.99187284")
        case .gold: return L10n.t("pawpetTraits.72b6677b")
        case .silver: return L10n.t("pawpetTraits.966b9392")
        case .bronze: return L10n.t("pawpetTraits.eae00398")
        case .none: return ""
        }
    }

    private var backdropReason: String {
        switch backdrop {
        case .rays: return L10n.t("pawpetTraits.50c9a682")
        case .orbit: return L10n.t("pawpetTraits.66fd5c7f")
        case .constellation: return L10n.t("pawpetTraits.2f8a3350")
        case .none: return ""
        }
    }

    private var auraReason: String {
        switch aura {
        case .dawn: return L10n.t("pawpetTraits.d13975ad")
        case .morning: return L10n.t("pawpetTraits.c3c5cb9d")
        case .afternoon: return L10n.t("pawpetTraits.ef048517")
        case .evening: return L10n.t("pawpetTraits.b2b31286")
        case .night: return L10n.t("pawpetTraits.0f5a4659")
        case .deepNight: return L10n.t("pawpetTraits.6d5d8242")
        }
    }

    /// Background wash for the aura, kept faint so the cat stays the subject.
    var auraColors: [Color] {
        switch aura {
        case .dawn: return [Color(red: 1.0, green: 0.78, blue: 0.58), Color(red: 0.98, green: 0.90, blue: 0.72)]
        case .morning: return [Color(red: 0.68, green: 0.88, blue: 0.98), Color(red: 0.90, green: 0.96, blue: 1.0)]
        case .afternoon: return [Color(red: 0.98, green: 0.92, blue: 0.60), Color(red: 1.0, green: 0.96, blue: 0.82)]
        case .evening: return [Color(red: 0.98, green: 0.62, blue: 0.48), Color(red: 0.80, green: 0.56, blue: 0.72)]
        case .night: return [Color(red: 0.36, green: 0.42, blue: 0.72), Color(red: 0.24, green: 0.28, blue: 0.52)]
        case .deepNight: return [Color(red: 0.18, green: 0.20, blue: 0.38), Color(red: 0.10, green: 0.11, blue: 0.24)]
        }
    }
}
