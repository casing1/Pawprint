import Foundation

/// Turns raw counters into everything the UI shows.
///
/// This is the composition, not the arithmetic. Each block below is a calculator in `Summary/` that
/// takes what it needs and touches only the fields it owns; the order is the one dependency between
/// them, and it is the reason this reads as a list rather than a graph — the pointer figures need
/// the display, the tags need the pointer figures, and the sentence needs everything.
///
/// Nothing here is persisted: a summary is recomputed from `DailyRawCounters` on demand, so display
/// logic can evolve without touching what is stored on disk.
package enum StatsEngine {

    /// The summary of one day.
    ///
    /// - Parameters:
    ///   - recentDays: the days before this one, used only by the closing sentence to say whether
    ///     today was quieter or busier than usual.
    ///   - machine: the display and battery the figures are measured against. Defaults to the
    ///     running machine's, which is where the two lookups that used to happen mid-calculation
    ///     now happen — once, visibly, at the call site.
    static package func summary(
        for raw: DailyRawCounters,
        recentDays: [DailyRawCounters] = [],
        dayStartHour: Int = 0,
        machine: MachineFacts = .current
    ) -> DailySummary {
        var s = DailySummary(day: raw.day)

        KeyboardStats.apply(raw, to: &s, dayStartHour: dayStartHour)
        PointerStats.apply(raw, to: &s, machine: machine)
        ClipboardStats.apply(raw, to: &s)
        AppStats.apply(raw, to: &s)
        TimeStats.apply(raw, to: &s)
        DeviceStats.apply(raw, to: &s, machine: machine)

        s.activityPerMinute = raw.activityPerMinute
        s.charKeysPerMinute = raw.charKeysPerMinute
        if let peak = raw.activityPerMinute.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
            s.busiestMinute = peak.offset
            s.busiestMinuteCount = peak.element
        }

        s.regretIndex = DerivedIndices.regret(raw: raw, backspaceRatio: s.backspaceRatio)
        s.chaosIndex = DerivedIndices.chaos(raw: raw)
        s.activityTags = DerivedIndices.activityTags(raw: raw, summary: s)
        s.energyFacts = FunConversions.energyFacts(fromBatteryPercent: s.batteryDrainedPercent,
                                                   machine: machine)
        s.fingerTravelMeters = FunConversions.fingerTravelMeters(keystrokes: s.totalKeyPresses)

        // These four read the summary as a whole, so they come last and in this order: the score
        // feeds the persona, and the sentence is written about everything above it.
        s.score = PawprintScore.build(from: s)
        s.persona = DailyPersona.build(from: s)
        s.highlights = HighlightBuilder.build(raw: raw, summary: s, dayStartHour: dayStartHour)
        s.funFacts = FunFactBuilder.build(raw: raw, summary: s, machine: machine)
        s.summarySentence = SummarySentence.build(raw: raw, summary: s, recentDays: recentDays)

        return s
    }
}
