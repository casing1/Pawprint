import Foundation

/// A single playful "how was today" number. Explicitly *not* a productivity rating — the copy
/// everywhere frames it as a summary of how busy the day looked, and a low score is described
/// as a quiet day rather than a failure (spec §1: 사용자 행동을 좋음/나쁨으로 단정하지 않는다).
struct PawprintScore {
    var total: Int              // 0...100
    var grade: String           // S / A / B / C / D
    var gradeColorHint: GradeTone
    var headline: String
    var components: [Component]

    struct Component: Identifiable {
        var id: String { label }
        var label: String
        var earned: Int
        var maximum: Int
    }

    enum GradeTone {
        case gold, green, blue, gray
    }

    /// Reference "a full day" values each component is measured against. Hitting these is not a
    /// goal to chase — they're just the point where a component stops adding more.
    private enum Reference {
        static let activeSeconds = 6.0 * 3600
        static let focusSeconds = 2.0 * 3600
        static let keyPresses = 8_000.0
        static let wpm = 80.0
    }

    static func build(from summary: DailySummary) -> PawprintScore {
        let activity = scaled(Double(summary.activeSeconds), reference: Reference.activeSeconds, max: 30)
        let focus = scaled(Double(summary.totalFocusSeconds), reference: Reference.focusSeconds, max: 30)
        let typing = scaled(Double(summary.totalKeyPresses), reference: Reference.keyPresses, max: 20)
        let speed = scaled(summary.maxWPM, reference: Reference.wpm, max: 20)

        let total = activity + focus + typing + speed
        let (grade, tone) = gradeFor(total)

        return PawprintScore(
            total: total,
            grade: grade,
            gradeColorHint: tone,
            headline: headlineFor(total: total, summary: summary),
            components: [
                Component(label: "활동량", earned: activity, maximum: 30),
                Component(label: "집중", earned: focus, maximum: 30),
                Component(label: "타이핑", earned: typing, maximum: 20),
                Component(label: "속도", earned: speed, maximum: 20),
            ]
        )
    }

    /// Square-root scaling so early activity feels rewarding and the curve flattens near the
    /// reference value instead of hard-clipping.
    private static func scaled(_ value: Double, reference: Double, max maxPoints: Int) -> Int {
        guard value > 0, reference > 0 else { return 0 }
        let ratio = min(value / reference, 1.0)
        return Int((ratio.squareRoot() * Double(maxPoints)).rounded())
    }

    private static func gradeFor(_ total: Int) -> (String, GradeTone) {
        switch total {
        case 85...: return ("S", .gold)
        case 70..<85: return ("A", .green)
        case 50..<70: return ("B", .blue)
        case 30..<50: return ("C", .gray)
        default: return ("D", .gray)
        }
    }

    private static func headlineFor(total: Int, summary: DailySummary) -> String {
        if summary.activeSeconds < 300 {
            return "아직 오늘이 시작되는 중이에요"
        }
        switch total {
        case 85...: return "폭발적인 하루였어요"
        case 70..<85: return "알차게 보낸 하루예요"
        case 50..<70: return "적당히 바빴던 하루예요"
        case 30..<50: return "여유로운 하루였어요"
        default: return "조용한 하루였어요. 그것도 좋죠"
        }
    }
}

/// Playful label for the shape of one day. Changes day to day by design — never a fixed label
/// for the person.
///
/// This used to be a switch on one number: keyboard actions as a share of all actions. Since
/// almost everyone types far more than they click, almost every day came back "키보드파", and the
/// label carried no information. Now ~25 candidates drawn from *different* metric families —
/// schedule, focus, typing quality, pointer habits, app spread, power, network, session shape —
/// each score how strongly today matches them, and the strongest one wins. The keyboard/pointer
/// axis is still in the running, but only as the floor when nothing else stands out.
struct DailyPersona {
    var title: String
    var emoji: String
    var detail: String
    /// 0 = entirely pointer-driven, 100 = entirely keyboard-driven.
    var keyboardAffinity: Int

    /// A persona plus how well today fits it.
    ///
    /// `strength` runs 1.0 (just cleared the bar) to 2.0 (unambiguously this kind of day). Every
    /// candidate is mapped onto that same span, because a raw "value ÷ threshold" is not
    /// comparable across metrics: copy-paste count can run to eight times its threshold while
    /// typing consistency tops out at 1.3×, so ratio scoring quietly hands the day to whichever
    /// metric happens to have the widest dynamic range.
    private struct Candidate {
        let title: String
        let emoji: String
        let detail: String
        let strength: Double
    }

    static func build(from summary: DailySummary) -> DailyPersona? {
        let keyboardActions = summary.totalKeyPresses
        let pointerActions = summary.totalClicks + summary.scrollDirectionChanges
        let totalActions = keyboardActions + pointerActions
        guard totalActions >= 50 else { return nil }

        let affinity = Int((Double(keyboardActions) / Double(totalActions) * 100).rounded())
        var candidates: [Candidate] = []

        /// `from` is the bar the day has to clear; `to` is where the day is emphatically this
        /// persona. Anything past `to` is still just 2.0 — more extreme isn't more distinctive.
        func consider(
            _ title: String,
            _ emoji: String,
            _ detail: String,
            value: Double,
            from: Double,
            to: Double,
            weight: Double = 1.0
        ) {
            guard value >= from, to > from else { return }
            let normalized = 1 + min(1, (value - from) / (to - from))
            candidates.append(Candidate(title: title, emoji: emoji, detail: detail,
                                        strength: normalized * weight))
        }

        let activeHours = Double(summary.activeSeconds) / 3600
        let calendar = Calendar.current
        let startHour = summary.firstActivity.map { calendar.component(.hour, from: $0) }
        let endHour = summary.lastActivity.map { calendar.component(.hour, from: $0) }
        let gigabyte = 1024.0 * 1024 * 1024

        // --- Schedule ---
        if let endHour, (0...4).contains(endHour) {
            consider("야행성 올빼미", "🦉", "새벽까지 불이 꺼지지 않았어요",
                     value: Double(5 - endHour), from: 1, to: 5)
        }
        if let startHour, startHour < 8 {
            consider("새벽 개척자", "🌅", "남들보다 먼저 하루를 열었어요",
                     value: Double(8 - startHour), from: 1, to: 4)
        }
        if let golden = summary.goldenHour, (11...14).contains(golden), activeHours >= 1 {
            consider("점심시간 전사", "🍱", "한낮에 가장 활발했어요",
                     value: activeHours, from: 1, to: 5, weight: 0.85)
        }
        if let golden = summary.goldenHour, (18...23).contains(golden), activeHours >= 1 {
            consider("저녁형 러너", "🌆", "해가 진 뒤에 속도가 붙었어요",
                     value: activeHours, from: 1, to: 5, weight: 0.85)
        }

        // --- Focus & attention ---
        consider("몰입 장인", "🎯", "한 번 시작하면 오래 붙잡고 있었어요",
                 value: Double(summary.longestFocusSeconds), from: 45 * 60, to: 120 * 60)
        if summary.activeSeconds > 1800 {
            consider("딥워크 수행자", "🧘", "쓴 시간의 대부분이 집중 시간이었어요",
                     value: Double(summary.totalFocusSeconds) / Double(summary.activeSeconds),
                     from: 0.45, to: 0.8)
        }
        if activeHours >= 1 {
            consider("산만한 다람쥐", "🐿️", "이 앱 저 앱 부지런히 옮겨 다녔어요",
                     value: Double(summary.totalAppSwitches) / activeHours, from: 60, to: 200)
        }
        consider("쉼표가 많은 하루", "☕️", "길게 쉬어가며 일했어요",
                 value: Double(summary.longestBreakSeconds), from: 2 * 3600, to: 6 * 3600,
                 weight: 0.85)

        // --- Typing quality ---
        if summary.totalKeyPresses >= 500 {
            consider("오타 지우개", "🩹", "쓰고 지우기를 반복한 하루였어요",
                     value: summary.backspaceRatio, from: 0.22, to: 0.42)
            consider("무결점 타이피스트", "✨", "거의 지우지 않고 써 내려갔어요",
                     value: 0.06 - summary.backspaceRatio, from: 0.002, to: 0.05)
            consider("꾸준한 리듬", "🎼", "타이핑 속도가 흔들림 없이 일정했어요",
                     value: Double(summary.typingConsistency), from: 72, to: 95)
        }
        consider("폭풍 타자", "🌪️", "순간 타속이 아주 빨랐어요",
                 value: summary.maxWPM, from: 95, to: 150)
        if summary.totalKeyPresses > 0 {
            let shortcuts = Double(summary.shortcutCounts.values.reduce(0, +))
            consider("단축키 닌자", "🥷", "마우스 대신 단축키로 해결했어요",
                     value: shortcuts / Double(summary.totalKeyPresses), from: 0.08, to: 0.25)
        }
        consider("단축키 수집가", "🗝️", "서로 다른 단축키를 두루 썼어요",
                 value: Double(summary.distinctShortcutsUsed), from: 10, to: 20)

        // --- Pointer habits ---
        consider("스크롤 무한동력", "🌀", "화면을 끝없이 내렸어요",
                 value: summary.scrollScreens, from: 250, to: 800)
        consider("클릭 연타왕", "👆", "한때 클릭이 폭발했어요",
                 value: Double(summary.maxClicksPerMinute), from: 55, to: 120)
        consider("드래그 장인", "✋", "끌어다 놓는 작업이 많았어요",
                 value: summary.dragDistanceMeters, from: 25, to: 100)
        consider("커서 마라토너", "🏃", "커서가 아주 먼 거리를 달렸어요",
                 value: summary.cursorDistanceMeters, from: 400, to: 1500)
        consider("복붙 연금술사", "🧪", "복사와 붙여넣기로 옮겨 담은 하루예요",
                 value: Double(summary.clipboardCopyCount + summary.clipboardPasteCount),
                 from: 80, to: 300)

        // --- App spread ---
        consider("한 우물 파는 사람", "📌", "거의 한 앱에서만 지냈어요",
                 value: Double(summary.appConcentration), from: 70, to: 95)
        consider("탭 유목민", "🏕️", "여러 앱을 옮겨 다니며 지냈어요",
                 value: Double(summary.appUsage.count), from: 12, to: 30, weight: 0.9)

        // --- Power & device ---
        let poweredSeconds = summary.secondsOnBattery + summary.secondsOnAC
        if poweredSeconds > 3600 {
            consider("배터리 마라토너", "🔋", "충전기 없이 오래 버텼어요",
                     value: Double(summary.secondsOnBattery), from: 5 * 3600, to: 12 * 3600)
            consider("콘센트 붙박이", "🔌", "거의 내내 충전기에 꽂혀 있었어요",
                     value: Double(summary.secondsOnAC) / Double(poweredSeconds),
                     from: 0.85, to: 1.0, weight: 0.85)
        }
        consider("노트북 유목민", "🎒", "뚜껑을 여닫으며 이동이 잦았어요",
                 value: Double(summary.lidOpenCount), from: 4, to: 12)
        consider("멀티 스크린 지휘자", "🖥️", "외부 디스플레이를 함께 썼어요",
                 value: Double(summary.maxSimultaneousDisplays), from: 2, to: 4, weight: 0.75)

        // --- Network ---
        consider("데이터 폭식가", "📡", "인터넷 데이터를 아주 많이 주고받았어요",
                 value: Double(summary.networkTotalBytes), from: 8 * gigabyte, to: 40 * gigabyte)
        consider("스트리밍 순례자", "📺", "내려받은 양이 영상 시청에 가까웠어요",
                 value: Double(summary.networkDownloadBytes), from: 4 * gigabyte, to: 20 * gigabyte,
                 weight: 0.9)

        // --- Session shape ---
        consider("장거리 주자", "🛣️", "아주 긴 하루를 보냈어요",
                 value: activeHours, from: 7, to: 12)
        if activeHours < 1.5 {
            consider("짧고 굵게", "⚡️", "짧게 앉아 많은 걸 해치웠어요",
                     value: summary.avgWPM, from: 45, to: 90)
        }
        if summary.screenOnSeconds > 2 * 3600 {
            consider("화면만 켜둔 사람", "💤", "화면은 켜져 있었지만 자리를 자주 비웠어요",
                     value: Double(100 - summary.screenUtilizationPercent), from: 70, to: 95,
                     weight: 0.85)
        }
        consider("혼돈의 지휘자", "🎢", "정신없이 몰아친 하루였어요",
                 value: summary.chaosIndex, from: 72, to: 95, weight: 0.9)

        // --- Floor: the keyboard/pointer axis, so there is always an answer ---
        candidates.append(keyboardPointerFallback(affinity: affinity))

        guard let winner = candidates.max(by: { $0.strength < $1.strength }) else { return nil }
        return DailyPersona(
            title: winner.title,
            emoji: winner.emoji,
            detail: winner.detail,
            keyboardAffinity: affinity
        )
    }

    /// Deliberately below every qualifying candidate's floor of 1.0: this only wins on a day
    /// that was not distinctly anything, which is exactly when "키보드파" is the honest answer.
    private static func keyboardPointerFallback(affinity: Int) -> Candidate {
        switch affinity {
        case 90...:
            return Candidate(title: "키보드 순수주의자", emoji: "⌨️",
                             detail: "마우스는 거의 쳐다보지도 않았어요", strength: 0.5)
        case 70..<90:
            return Candidate(title: "키보드파", emoji: "⌨️",
                             detail: "손이 자판 위에 오래 머물렀어요", strength: 0.5)
        case 45..<70:
            return Candidate(title: "균형잡힌 사용자", emoji: "⚖️",
                             detail: "키보드와 포인터를 골고루 썼어요", strength: 0.5)
        case 20..<45:
            return Candidate(title: "마우스파", emoji: "🖱️",
                             detail: "포인터로 세상을 탐험했어요", strength: 0.5)
        default:
            return Candidate(title: "마우스 탐험가", emoji: "🧭",
                             detail: "오늘은 거의 클릭과 스크롤로 보냈어요", strength: 0.5)
        }
    }
}
