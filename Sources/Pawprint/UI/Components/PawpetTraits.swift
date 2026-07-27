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
    static let palettes: [(name: String, body: Color, accent: Color)] = [
        ("치즈", Color(red: 0.98, green: 0.76, blue: 0.42), Color(red: 0.86, green: 0.55, blue: 0.22)),
        ("고등어", Color(red: 0.65, green: 0.70, blue: 0.80), Color(red: 0.42, green: 0.47, blue: 0.60)),
        ("먹눈", Color(red: 0.38, green: 0.36, blue: 0.44), Color(red: 0.24, green: 0.22, blue: 0.30)),
        ("크림", Color(red: 0.96, green: 0.93, blue: 0.87), Color(red: 0.80, green: 0.74, blue: 0.66)),
        ("라일락", Color(red: 0.72, green: 0.58, blue: 0.88), Color(red: 0.55, green: 0.42, blue: 0.72)),
        ("민트", Color(red: 0.52, green: 0.78, blue: 0.72), Color(red: 0.32, green: 0.58, blue: 0.54)),
        ("복숭아", Color(red: 0.95, green: 0.66, blue: 0.62), Color(red: 0.80, green: 0.46, blue: 0.44)),
        ("카라멜", Color(red: 0.78, green: 0.56, blue: 0.36), Color(red: 0.56, green: 0.38, blue: 0.22)),
        ("스모크", Color(red: 0.55, green: 0.56, blue: 0.62), Color(red: 0.36, green: 0.37, blue: 0.43)),
        ("하늘", Color(red: 0.60, green: 0.76, blue: 0.92), Color(red: 0.38, green: 0.56, blue: 0.76)),
        ("올리브", Color(red: 0.72, green: 0.76, blue: 0.52), Color(red: 0.50, green: 0.55, blue: 0.32)),
        ("장미", Color(red: 0.90, green: 0.58, blue: 0.70), Color(red: 0.72, green: 0.38, blue: 0.52)),
        ("모래", Color(red: 0.90, green: 0.82, blue: 0.66), Color(red: 0.70, green: 0.60, blue: 0.44)),
        ("코발트", Color(red: 0.48, green: 0.54, blue: 0.86), Color(red: 0.32, green: 0.36, blue: 0.66)),
    ]

    /// Iris colours. Real cats have a narrow range; these stretch it a little for variety.
    static let eyeColors: [(name: String, color: Color)] = [
        ("호박", Color(red: 0.95, green: 0.70, blue: 0.20)),
        ("에메랄드", Color(red: 0.24, green: 0.72, blue: 0.48)),
        ("사파이어", Color(red: 0.30, green: 0.52, blue: 0.92)),
        ("구리", Color(red: 0.82, green: 0.45, blue: 0.18)),
        ("금", Color(red: 0.98, green: 0.84, blue: 0.36)),
        ("연둣빛", Color(red: 0.62, green: 0.82, blue: 0.36)),
        ("잿빛", Color(red: 0.62, green: 0.66, blue: 0.72)),
        ("자수정", Color(red: 0.68, green: 0.44, blue: 0.86)),
    ]

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

    init(day: String, summary: DailySummary, streakDays: Int = 0, isCelebrating: Bool = false) {
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

        expression = Self.expression(summary, score: score, isCelebrating: isCelebrating)
        headwear = Self.headwear(summary, score: score, isCelebrating: isCelebrating)
        eyewear = Self.eyewear(summary)
        prop = Self.prop(summary)
        collar = Self.collar(streakDays: streakDays)
        cheekMark = Self.cheekMark(summary, score: score)
        aura = Self.aura(summary)
        floaters = Self.floaters(summary, isCelebrating: isCelebrating)

        // Rewards. `generator` has already been advanced by the identity draws, so the charm and
        // wing choices vary from day to day without needing a second seed.
        pawCharm = Self.pawCharm(summary, generator: &generator)
        frame = Self.frame(score: score, isCelebrating: isCelebrating)
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

    private static func expression(_ s: DailySummary, score: Int, isCelebrating: Bool) -> Expression {
        if isCelebrating { return .sparkle }
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

    private static func headwear(_ s: DailySummary, score: Int, isCelebrating: Bool) -> Headwear {
        if isCelebrating { return .partyHat }
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

    private static func floaters(_ s: DailySummary, isCelebrating: Bool) -> Floaters {
        if isCelebrating { return .sparkles }
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

    private static func frame(score: Int, isCelebrating: Bool) -> Frame {
        if isCelebrating { return .prismatic }
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
            ("액자", frame == .none ? "없음" : frameName, framePoints, 32),
            ("발 장식", pawCharm == .none ? "없음" : pawCharmName, pawCharm == .none ? 0 : 20, 20),
            ("날개", wings == .none ? "없음" : wingsName, wings == .none ? 0 : 16, 16),
            ("배경", backdropName, backdropPoints, 12),
            ("목걸이", collar == .none ? "없음" : collarName, collarPoints, 8),
            ("머리", headwear == .none ? "없음" : headwearName, headwearPoints, 6),
            ("표정", caption, expressionPoints, 4),
            ("주변", floaters == .none ? "없음" : floatersName, floaters == .none ? 0 : 2, 2)
        ]
    }

    private var framePoints: Double {
        switch frame {
        case .none: return 0
        case .bronze: return 8
        case .silver: return 16
        case .gold: return 24
        case .prismatic: return 32
        }
    }

    private var backdropPoints: Double {
        switch backdrop {
        case .none: return 0
        case .orbit: return 6
        case .constellation: return 8
        case .rays: return 12
        }
    }

    private var collarPoints: Double {
        switch collar {
        case .none: return 0
        case .cloth: return 1
        case .blue: return 2
        case .green: return 3
        case .gold: return 5
        case .rainbow: return 8
        }
    }

    private var headwearPoints: Double {
        switch headwear {
        case .none: return 0
        case .bandana, .beanie: return 2
        case .nightcap, .headphones: return 3
        case .halo: return 4
        case .crown: return 5
        case .partyHat: return 6
        }
    }

    /// Expressions you only see on an unusual day score higher than the everyday ones.
    private var expressionPoints: Double {
        switch expression {
        case .content: return 0
        case .wide, .sleepy: return 1
        case .tired, .zen, .mischief: return 2
        case .dizzy, .chaotic, .surprised, .focused: return 3
        case .determined, .sparkle: return 4
        }
    }

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
        case "S": return "전설"
        case "A": return "희귀"
        case "B": return "고급"
        case "C": return "일반"
        default: return "평범"
        }
    }

    // MARK: - Trait names

    var wingsName: String {
        switch wings {
        case .none: return "없음"
        case .feathered: return "깃털 날개"
        case .crystal: return "수정 날개"
        case .ember: return "불꽃 날개"
        }
    }

    var backdropName: String {
        switch backdrop {
        case .none: return "없음"
        case .rays: return "빛줄기"
        case .orbit: return "궤도"
        case .constellation: return "별자리"
        }
    }

    var collarName: String {
        switch collar {
        case .none: return "없음"
        case .cloth: return "천 목걸이"
        case .blue: return "파란 목걸이"
        case .green: return "초록 목걸이"
        case .gold: return "금 목걸이"
        case .rainbow: return "무지개 목걸이"
        }
    }

    var headwearName: String {
        switch headwear {
        case .none: return "없음"
        case .crown: return "왕관"
        case .partyHat: return "파티모자"
        case .halo: return "후광"
        case .headphones: return "헤드폰"
        case .nightcap: return "수면모자"
        case .beanie: return "비니"
        case .bandana: return "두건"
        }
    }

    var floatersName: String {
        switch floaters {
        case .none: return "없음"
        case .zzz: return "zzz"
        case .sparkles: return "반짝임"
        case .notes: return "음표"
        case .bits: return "데이터"
        }
    }

    var eyewearName: String {
        switch eyewear {
        case .none: return "없음"
        case .readingGlasses: return "안경"
        case .sunglasses: return "선글라스"
        }
    }

    var propName: String {
        switch prop {
        case .none: return "없음"
        case .coffee: return "커피"
        case .mouse: return "마우스"
        case .plug: return "충전"
        case .yarn: return "실뭉치"
        case .moon: return "달"
        case .book: return "책"
        case .fish: return "생선"
        }
    }

    // MARK: - Explanations

    /// One-line headline for the card.
    var caption: String {
        switch expression {
        case .sparkle: return "축하 중!"
        case .sleepy: return "아직 졸려요"
        case .dizzy: return "수정이 많은 하루"
        case .chaotic: return "정신없는 하루"
        case .surprised: return "깜짝 놀란 하루"
        case .determined: return "질주하는 하루"
        case .focused: return "집중하고 있어요"
        case .mischief: return "여기저기 기웃거린 하루"
        case .tired: return "화면만 오래 켜둔 하루"
        case .zen: return "느긋한 하루"
        case .wide: return "신나 보여요"
        case .content: return "평범한 하루"
        }
    }

    /// Why each visible trait looks the way it does. The cat is only interesting if you can read
    /// it, so the card lists the ones that are actually showing.
    var notes: [(trait: String, reason: String)] {
        var out: [(String, String)] = []
        out.append(("표정", expressionReason))
        if headwear != .none { out.append(("머리", headwearReason)) }
        if eyewear != .none { out.append(("안경", eyewearReason)) }
        if prop != .none { out.append(("소품", propReason)) }
        if collar != .none { out.append(("목걸이", collarReason)) }
        if cheekMark != .none { out.append(("볼", cheekReason)) }
        if floaters != .none { out.append(("주변", floatersReason)) }
        if pawCharm != .none { out.append(("발", pawCharmReason)) }
        if wings != .none { out.append(("날개", wingsReason)) }
        if frame != .none { out.append(("액자", frameReason)) }
        if backdrop != .none { out.append(("배경", backdropReason)) }
        out.append(("분위기", auraReason))
        out.append(("털", "\(Self.palettes[paletteIndex].name)색 \(patternName) · \(Self.eyeColors[eyeColorIndex].name)빛 눈 — 날짜로 정해져요"))
        return out
    }

    var patternName: String {
        switch pattern {
        case .plain: return "민무늬"
        case .tabby: return "줄무늬"
        case .spotted: return "점박이"
        case .tuxedo: return "턱시도"
        case .calico: return "삼색"
        case .colorpoint: return "포인트"
        case .bicolor: return "바이컬러"
        case .star: return "별무늬"
        }
    }

    private var expressionReason: String {
        switch expression {
        case .sparkle: return "신기록이나 레벨업을 축하하는 중이에요"
        case .sleepy: return "오늘 활동 시간이 5분도 안 됐어요"
        case .dizzy: return "지운 키 비율이 30%를 넘었어요"
        case .chaotic: return "혼돈 지수가 70 이상이에요"
        case .surprised: return "1분에 60번 넘게 클릭한 순간이 있었어요"
        case .determined: return "최고 타속이 100 WPM을 넘었어요"
        case .focused: return "45분 넘게 한 앱에 집중했어요"
        case .mischief: return "앱을 200번 넘게 전환했어요"
        case .tired: return "화면은 오래 켜져 있었는데 실사용 비율이 낮아요"
        case .zen: return "2시간 넘게 길게 쉬었어요"
        case .wide: return "오늘 점수가 75점을 넘었어요"
        case .content: return "특별히 튀는 지표 없이 무난한 하루예요"
        }
    }

    private var headwearReason: String {
        switch headwear {
        case .partyHat: return "축하할 일이 생겼어요"
        case .crown: return "오늘 점수가 85점을 넘었어요"
        case .halo: return "많이 쳤는데도 후회 지수가 낮아요"
        case .headphones: return "오디오 출력 장치를 여러 번 바꿨어요"
        case .nightcap: return "새벽까지 작업했어요"
        case .beanie: return "노트북 뚜껑을 세 번 이상 여닫았어요"
        case .bandana: return "서로 다른 단축키를 10종류 이상 썼어요"
        case .none: return ""
        }
    }

    private var eyewearReason: String {
        switch eyewear {
        case .sunglasses: return "화면이 8시간 넘게 켜져 있었어요"
        case .readingGlasses: return "문자 키를 8,000자 넘게 입력했어요"
        case .none: return ""
        }
    }

    private var propReason: String {
        switch prop {
        case .moon: return "자정을 넘겨 새벽까지 썼어요"
        case .coffee: return "오전 8시 전에 하루를 시작했어요"
        case .book: return "문자 입력이 20,000자를 넘었어요"
        case .mouse: return "클릭이 2,000번을 넘었어요"
        case .yarn: return "스크롤 방향을 300번 넘게 바꿨어요"
        case .plug: return "대부분의 시간을 충전기에 꽂아둔 채로 썼어요"
        case .fish: return "Mac이 2시간 넘게 잠들어 있었어요"
        case .none: return ""
        }
    }

    private var collarReason: String {
        switch collar {
        case .cloth: return "연속 기록 1~2일째"
        case .blue: return "연속 기록 3~6일째"
        case .green: return "연속 기록 7~13일째"
        case .gold: return "연속 기록 14~29일째"
        case .rainbow: return "연속 기록 30일 이상"
        case .none: return ""
        }
    }

    private var cheekReason: String {
        switch cheekMark {
        case .flushed: return "Mac이 뜨거워진 시간이 있었어요"
        case .sweat: return "최고 타속이 120 WPM을 넘었어요"
        case .blush: return "오늘 점수가 60점을 넘었어요"
        case .none: return ""
        }
    }

    private var floatersReason: String {
        switch floaters {
        case .sparkles: return "기록을 갱신했어요"
        case .zzz: return "자리를 비운 시간이 사용 시간보다 훨씬 길어요"
        case .bits: return "인터넷 데이터를 5GB 넘게 주고받았어요"
        case .notes: return "오디오 장치를 세 번 이상 바꿨어요"
        case .none: return ""
        }
    }

    var pawCharmName: String {
        switch pawCharm {
        case .none: return ""
        case .orb: return "빛의 구슬"
        case .gauntlet: return "빛나는 건틀릿"
        case .star: return "별빛 조각"
        case .ring: return "고리 장식"
        case .flame: return "타오르는 불꽃"
        case .crystal: return "수정 결정"
        case .feather: return "빛깃털"
        }
    }

    private var pawCharmReason: String {
        "키를 4,000번 넘게 눌러 \(pawCharmName)을 얻었어요 (장식은 날마다 랜덤)"
    }

    private var wingsReason: String {
        switch wings {
        case .feathered: return "아주 먼 거리를 스크롤·이동해 깃털 날개가 돋았어요"
        case .crystal: return "아주 먼 거리를 스크롤·이동해 수정 날개가 돋았어요"
        case .ember: return "아주 먼 거리를 스크롤·이동해 불꽃 날개가 돋았어요"
        case .none: return ""
        }
    }

    var frameName: String {
        switch frame {
        case .none: return ""
        case .bronze: return "동 액자"
        case .silver: return "은 액자"
        case .gold: return "금 액자"
        case .prismatic: return "무지개 액자"
        }
    }

    private var frameReason: String {
        switch frame {
        case .prismatic: return "S 등급 — 가장 높은 등급의 액자예요"
        case .gold: return "A 등급 액자예요"
        case .silver: return "B 등급 액자예요"
        case .bronze: return "C 등급 액자예요"
        case .none: return ""
        }
    }

    private var backdropReason: String {
        switch backdrop {
        case .rays: return "점수 80점을 넘겨 뒤에서 빛이 뻗어나와요"
        case .orbit: return "앱을 150번 넘게 전환해 궤도가 돌고 있어요"
        case .constellation: return "새벽까지 이어진 하루라 별자리가 떴어요"
        case .none: return ""
        }
    }

    private var auraReason: String {
        switch aura {
        case .dawn: return "하루의 정점이 이른 아침이었어요"
        case .morning: return "하루의 정점이 오전이었어요"
        case .afternoon: return "하루의 정점이 오후였어요"
        case .evening: return "하루의 정점이 저녁이었어요"
        case .night: return "하루의 정점이 밤이었어요"
        case .deepNight: return "하루의 정점이 새벽이었어요"
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
