import Foundation

/// One or two sentences describing the day, compared against the days before it.
///
/// Deliberately never a judgement. It reports what happened — quieter than usual, fastest at this
/// time, focused for this long — and stops there.
package enum SummarySentence {

    package static func build(raw: DailyRawCounters, summary: DailySummary, recentDays: [DailyRawCounters]) -> String {
        guard raw.totalKeyPresses > 0 || summary.activeSeconds > 0 else {
            return L10n.t("statsEngine.0f6bab4e")
        }

        var parts: [String] = []

        if !recentDays.isEmpty {
            let avgKeys = Double(recentDays.map(\.totalKeyPresses).reduce(0, +)) / Double(recentDays.count)
            if avgKeys > 0 {
                let diffPercent = ((Double(raw.totalKeyPresses) - avgKeys) / avgKeys) * 100
                if abs(diffPercent) >= 8 {
                    let direction = diffPercent >= 0 ? L10n.t("statsEngine.6ebc2f8b") : L10n.t("statsEngine.730ba352")
                    parts.append(L10n.t("statsEngine.644f182d", Int(abs(diffPercent)), direction))
                }
            }
        }

        if summary.maxWPM > 0, let time = summary.maxWPMTime {
            parts.append(L10n.t("statsEngine.d4eec037", Formatters.time(time), Formatters.wpm(summary.maxWPM)))
        }

        if summary.longestFocusSeconds >= 300 {
            parts.append(L10n.t("statsEngine.09912d56", Formatters.longDuration(summary.longestFocusSeconds)))
        }

        if parts.isEmpty {
            parts.append(L10n.t("statsEngine.a3fab626"))
        }

        return parts.prefix(2).joined(separator: " ")
    }
}
