import Foundation

/// A single playful "how was today" number. Explicitly *not* a productivity rating — the copy
/// everywhere frames it as a summary of how busy the day looked, and a low score is described
/// as a quiet day rather than a failure (spec §1: 사용자 행동을 좋음/나쁨으로 단정하지 않는다).
package struct PawprintScore {
    package var total: Int              // 0...100
    package var grade: String           // S / A / B / C / D
    package var gradeColorHint: GradeTone
    package var headline: String
    package var components: [Component]

    package struct Component: Identifiable {
        package var id: String { label }
        package var label: String
        package var earned: Int
        package var maximum: Int
    }

    package enum GradeTone {
        case gold, green, blue, gray
    }

    /// Reference "a full day" values each component is measured against. Hitting these is not a
    /// goal to chase — they're just the point where a component stops adding more.
    private enum Reference {
        package static let activeSeconds = 6.0 * 3600
        package static let focusSeconds = 2.0 * 3600
        package static let keyPresses = 8_000.0
        package static let wpm = 80.0
    }

    static package func build(from summary: DailySummary) -> PawprintScore {
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
                Component(label: L10n.t("pawprintScore.2a22907d"), earned: activity, maximum: 30),
                Component(label: L10n.t("pawprintScore.56fb8019"), earned: focus, maximum: 30),
                Component(label: L10n.t("pawprintScore.24ad1fbd"), earned: typing, maximum: 20),
                Component(label: L10n.t("pawprintScore.e8a20d8c"), earned: speed, maximum: 20),
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
            return L10n.t("pawprintScore.70b72769")
        }
        switch total {
        case 85...: return L10n.t("pawprintScore.be012852")
        case 70..<85: return L10n.t("pawprintScore.98ef8834")
        case 50..<70: return L10n.t("pawprintScore.9dc07c42")
        case 30..<50: return L10n.t("pawprintScore.2fd8a546")
        default: return L10n.t("pawprintScore.38297634")
        }
    }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(total: Int,
                 grade: String,
                 gradeColorHint: GradeTone,
                 headline: String,
                 components: [Component]) {
        self.total = total
        self.grade = grade
        self.gradeColorHint = gradeColorHint
        self.headline = headline
        self.components = components
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
package struct DailyPersona {
    package var title: String
    package var emoji: String
    package var detail: String
    /// 0 = entirely pointer-driven, 100 = entirely keyboard-driven.
    package var keyboardAffinity: Int

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

    static package func build(from summary: DailySummary) -> DailyPersona? {
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
            consider(L10n.t("pawprintScore.ebd1a951"), "🦉", L10n.t("pawprintScore.b72fba8a"),
                     value: Double(5 - endHour), from: 1, to: 5)
        }
        if let startHour, startHour < 8 {
            consider(L10n.t("pawprintScore.4c8260c4"), "🌅", L10n.t("pawprintScore.603c580d"),
                     value: Double(8 - startHour), from: 1, to: 4)
        }
        if let golden = summary.goldenHour, (11...14).contains(golden), activeHours >= 1 {
            consider(L10n.t("pawprintScore.ef9dd803"), "🍱", L10n.t("pawprintScore.f4081e52"),
                     value: activeHours, from: 1, to: 5, weight: 0.85)
        }
        if let golden = summary.goldenHour, (18...23).contains(golden), activeHours >= 1 {
            consider(L10n.t("pawprintScore.4ec85785"), "🌆", L10n.t("pawprintScore.c0763f52"),
                     value: activeHours, from: 1, to: 5, weight: 0.85)
        }

        // --- Focus & attention ---
        consider(L10n.t("pawprintScore.49847c4e"), "🎯", L10n.t("pawprintScore.e5dd2b7b"),
                 value: Double(summary.longestFocusSeconds), from: 45 * 60, to: 120 * 60)
        if summary.activeSeconds > 1800 {
            consider(L10n.t("pawprintScore.8d6d1765"), "🧘", L10n.t("pawprintScore.48c82b75"),
                     value: Double(summary.totalFocusSeconds) / Double(summary.activeSeconds),
                     from: 0.45, to: 0.8)
        }
        if activeHours >= 1 {
            consider(L10n.t("pawprintScore.516ddea4"), "🐿️", L10n.t("pawprintScore.e484776a"),
                     value: Double(summary.totalAppSwitches) / activeHours, from: 60, to: 200)
        }
        consider(L10n.t("pawprintScore.d8ef444f"), "☕️", L10n.t("pawprintScore.8fe68e0e"),
                 value: Double(summary.longestBreakSeconds), from: 2 * 3600, to: 6 * 3600,
                 weight: 0.85)

        // --- Typing quality ---
        if summary.totalKeyPresses >= 500 {
            consider(L10n.t("pawprintScore.2d5610d6"), "🩹", L10n.t("pawprintScore.19eb4873"),
                     value: summary.backspaceRatio, from: 0.22, to: 0.42)
            consider(L10n.t("pawprintScore.dc61d857"), "✨", L10n.t("pawprintScore.92df5aef"),
                     value: 0.06 - summary.backspaceRatio, from: 0.002, to: 0.05)
            consider(L10n.t("pawprintScore.4c59bd46"), "🎼", L10n.t("pawprintScore.0495e393"),
                     value: Double(summary.typingConsistency), from: 72, to: 95)
        }
        consider(L10n.t("pawprintScore.56bed287"), "🌪️", L10n.t("pawprintScore.8198e627"),
                 value: summary.maxWPM, from: 95, to: 150)
        if summary.totalKeyPresses > 0 {
            let shortcuts = Double(summary.shortcutCounts.values.reduce(0, +))
            consider(L10n.t("pawprintScore.840373c3"), "🥷", L10n.t("pawprintScore.77200230"),
                     value: shortcuts / Double(summary.totalKeyPresses), from: 0.08, to: 0.25)
        }
        consider(L10n.t("pawprintScore.6cb7d9e0"), "🗝️", L10n.t("pawprintScore.3a98dba8"),
                 value: Double(summary.distinctShortcutsUsed), from: 10, to: 20)

        // --- Pointer habits ---
        consider(L10n.t("pawprintScore.f9b9b332"), "🌀", L10n.t("pawprintScore.29b4326d"),
                 value: summary.scrollScreens, from: 250, to: 800)
        consider(L10n.t("pawprintScore.3b30ff2d"), "👆", L10n.t("pawprintScore.6e9be967"),
                 value: Double(summary.maxClicksPerMinute), from: 55, to: 120)
        consider(L10n.t("pawprintScore.c26a9f99"), "✋", L10n.t("pawprintScore.c24269bf"),
                 value: summary.dragDistanceMeters, from: 25, to: 100)
        consider(L10n.t("pawprintScore.5c5e4fba"), "🏃", L10n.t("pawprintScore.6530a49b"),
                 value: summary.cursorDistanceMeters, from: 400, to: 1500)
        consider(L10n.t("pawprintScore.f61aa37a"), "🧪", L10n.t("pawprintScore.0c2c69a3"),
                 value: Double(summary.clipboardCopyCount + summary.clipboardPasteCount),
                 from: 80, to: 300)

        // --- App spread ---
        consider(L10n.t("pawprintScore.f08717e0"), "📌", L10n.t("pawprintScore.06db64eb"),
                 value: Double(summary.appConcentration), from: 70, to: 95)
        consider(L10n.t("pawprintScore.d5944196"), "🏕️", L10n.t("pawprintScore.7b10494c"),
                 value: Double(summary.appUsage.count), from: 12, to: 30, weight: 0.9)

        // --- Power & device ---
        let poweredSeconds = summary.secondsOnBattery + summary.secondsOnAC
        if poweredSeconds > 3600 {
            consider(L10n.t("pawprintScore.16f20990"), "🔋", L10n.t("pawprintScore.a751e5ca"),
                     value: Double(summary.secondsOnBattery), from: 5 * 3600, to: 12 * 3600)
            consider(L10n.t("pawprintScore.65c812b9"), "🔌", L10n.t("pawprintScore.e14f0f7d"),
                     value: Double(summary.secondsOnAC) / Double(poweredSeconds),
                     from: 0.85, to: 1.0, weight: 0.85)
        }
        consider(L10n.t("pawprintScore.57ce1579"), "🎒", L10n.t("pawprintScore.e1b72caf"),
                 value: Double(summary.lidOpenCount), from: 4, to: 12)
        consider(L10n.t("pawprintScore.54b98485"), "🖥️", L10n.t("pawprintScore.f35c3212"),
                 value: Double(summary.maxSimultaneousDisplays), from: 2, to: 4, weight: 0.75)

        // --- Network ---
        consider(L10n.t("pawprintScore.fee55427"), "📡", L10n.t("pawprintScore.8ab86f72"),
                 value: Double(summary.networkTotalBytes), from: 8 * gigabyte, to: 40 * gigabyte)
        consider(L10n.t("pawprintScore.fd8d57fd"), "📺", L10n.t("pawprintScore.bbe77f79"),
                 value: Double(summary.networkDownloadBytes), from: 4 * gigabyte, to: 20 * gigabyte,
                 weight: 0.9)

        // --- Session shape ---
        consider(L10n.t("pawprintScore.8daa0fd2"), "🛣️", L10n.t("pawprintScore.49044460"),
                 value: activeHours, from: 7, to: 12)
        if activeHours < 1.5 {
            consider(L10n.t("pawprintScore.fea99619"), "⚡️", L10n.t("pawprintScore.626b26ef"),
                     value: summary.avgWPM, from: 45, to: 90)
        }
        if summary.screenOnSeconds > 2 * 3600 {
            consider(L10n.t("pawprintScore.70d0e0a7"), "💤", L10n.t("pawprintScore.a36e059e"),
                     value: Double(100 - summary.screenUtilizationPercent), from: 70, to: 95,
                     weight: 0.85)
        }
        consider(L10n.t("pawprintScore.070be460"), "🎢", L10n.t("pawprintScore.f7b12ea0"),
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
            return Candidate(title: L10n.t("pawprintScore.85b9389d"), emoji: "⌨️",
                             detail: L10n.t("pawprintScore.112bfc05"), strength: 0.5)
        case 70..<90:
            return Candidate(title: L10n.t("pawprintScore.abeed745"), emoji: "⌨️",
                             detail: L10n.t("pawprintScore.9a31a976"), strength: 0.5)
        case 45..<70:
            return Candidate(title: L10n.t("pawprintScore.c782142d"), emoji: "⚖️",
                             detail: L10n.t("pawprintScore.cbe5de46"), strength: 0.5)
        case 20..<45:
            return Candidate(title: L10n.t("pawprintScore.7c58c46d"), emoji: "🖱️",
                             detail: L10n.t("pawprintScore.a2f763d6"), strength: 0.5)
        default:
            return Candidate(title: L10n.t("pawprintScore.38e3c4ab"), emoji: "🧭",
                             detail: L10n.t("pawprintScore.0111a2ee"), strength: 0.5)
        }
    }
}
