import Foundation

/// Where today sits among every day ever recorded, for one metric.
package struct PercentileRanking: Identifiable {
    package var id: String { metricID }
    package var metricID: String
    package var title: String
    package var icon: String
    /// 1 = today is the best day on record, 100 = the quietest.
    package var topPercent: Int
    /// 1-based position among all recorded days, best first.
    package var rank: Int
    package var totalDays: Int
    package var displayValue: String

    /// Reads naturally in the UI: "상위 8%" for a strong day, plain rank for a small history.
    package var label: String {
        totalDays < 10 ? L10n.t("percentileEngine.d9027497", totalDays, rank) : L10n.t("percentileEngine.8ea91d0d", topPercent)
    }

    package var isStandout: Bool { topPercent <= 25 && totalDays >= 3 }
}

/// Computes today's percentile against the full history.
///
/// Past values are cached as pre-sorted arrays when the lifetime stats refresh, so the per-refresh
/// cost is a binary search rather than another pass over the database — this runs on the same
/// cadence as the today-summary and must stay cheap.
package enum PercentileEngine {

    /// Metrics worth ranking. Ratios and percentages are excluded: being in the "top 10% of
    /// keyboard-share days" says nothing meaningful about how the day went.
    static package let rankedMetricIDs = ["activeTime", "totalKeys", "focusTime", "totalClicks", "screenOnTime"]

    /// Builds the sorted sample arrays used for ranking. Days with no activity are skipped so an
    /// idle day can't inflate today's standing.
    static package func buildSamples(fromPastDays past: [DailySummary]) -> [String: [Double]] {
        let meaningful = past.filter { $0.activeSeconds > 0 || $0.totalKeyPresses > 0 }
        var samples: [String: [Double]] = [:]

        for id in rankedMetricIDs {
            guard let metric = MetricCatalog.metric(id: id) else { continue }
            samples[id] = meaningful.map { metric.value($0) }.sorted()
        }
        // The composite score gets its own entry — it's the single best answer to "how busy
        // was today", which is the question being asked.
        samples[scoreKey] = meaningful.compactMap { $0.score.map { Double($0.total) } }.sorted()
        return samples
    }

    static package let scoreKey = "pawprintScore"

    static package func rankings(for today: DailySummary, samples: [String: [Double]]) -> [PercentileRanking] {
        var result: [PercentileRanking] = []

        if let scoreSamples = samples[scoreKey], let score = today.score, score.total > 0 {
            result.append(ranking(
                metricID: scoreKey,
                title: L10n.t("percentileEngine.c0849f0a"),
                icon: "star.fill",
                todayValue: Double(score.total),
                display: L10n.t("percentileEngine.f0b5b795", score.total),
                sorted: scoreSamples
            ))
        }

        for id in rankedMetricIDs {
            guard let metric = MetricCatalog.metric(id: id),
                  let sorted = samples[id] else { continue }
            let value = metric.value(today)
            guard value > 0 else { continue }
            result.append(ranking(
                metricID: id,
                title: metric.title,
                icon: metric.icon,
                todayValue: value,
                display: metric.display(today),
                sorted: sorted
            ))
        }

        return result.sorted { $0.topPercent < $1.topPercent }
    }

    private static func ranking(
        metricID: String,
        title: String,
        icon: String,
        todayValue: Double,
        display: String,
        sorted: [Double]
    ) -> PercentileRanking {
        // Standard competition ranking: position is one past however many days genuinely beat
        // today. Ties share the better rank — the composite score saturates at 100, so matching
        // your best day should read as "1위", not get pushed down by the tie.
        let better = countAbove(todayValue, in: sorted)
        let totalDays = sorted.count + 1          // past days plus today
        let rank = better + 1                     // 1 = best
        // Clamped to 99: "상위 100%" is technically correct but reads like a broken stat.
        let topPercent = min(99, max(1, Int(ceil(Double(rank) / Double(totalDays) * 100))))

        return PercentileRanking(
            metricID: metricID,
            title: title,
            icon: icon,
            topPercent: topPercent,
            rank: rank,
            totalDays: totalDays,
            displayValue: display
        )
    }

    /// Number of entries strictly greater than `value` in an ascending array.
    private static func countAbove(_ value: Double, in sorted: [Double]) -> Int {
        // Upper bound: first index whose element is > value.
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] <= value { low = mid + 1 } else { high = mid }
        }
        return sorted.count - low
    }

    /// One-line verdict for the headline, phrased without judgement — a quiet day is just quiet.
    static package func headline(for ranking: PercentileRanking) -> String {
        guard ranking.totalDays >= 3 else {
            return L10n.t("percentileEngine.1ce14e82")
        }
        switch ranking.topPercent {
        case ...5: return L10n.t("percentileEngine.458c561e")
        case 6...15: return L10n.t("percentileEngine.1790d0b4")
        case 16...35: return L10n.t("percentileEngine.77295a1d")
        case 36...65: return L10n.t("percentileEngine.62411d0e")
        case 66...85: return L10n.t("percentileEngine.86ef14fb")
        default: return L10n.t("percentileEngine.aeb41031")
        }
    }
}
