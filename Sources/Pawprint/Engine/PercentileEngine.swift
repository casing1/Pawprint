import Foundation

/// Where today sits among every day ever recorded, for one metric.
struct PercentileRanking: Identifiable {
    var id: String { metricID }
    var metricID: String
    var title: String
    var icon: String
    /// 1 = today is the best day on record, 100 = the quietest.
    var topPercent: Int
    /// 1-based position among all recorded days, best first.
    var rank: Int
    var totalDays: Int
    var displayValue: String

    /// Reads naturally in the UI: "상위 8%" for a strong day, plain rank for a small history.
    var label: String {
        totalDays < 10 ? "\(totalDays)일 중 \(rank)위" : "상위 \(topPercent)%"
    }

    var isStandout: Bool { topPercent <= 25 && totalDays >= 3 }
}

/// Computes today's percentile against the full history.
///
/// Past values are cached as pre-sorted arrays when the lifetime stats refresh, so the per-refresh
/// cost is a binary search rather than another pass over the database — this runs on the same
/// cadence as the today-summary and must stay cheap.
enum PercentileEngine {

    /// Metrics worth ranking. Ratios and percentages are excluded: being in the "top 10% of
    /// keyboard-share days" says nothing meaningful about how the day went.
    static let rankedMetricIDs = ["activeTime", "totalKeys", "focusTime", "totalClicks", "screenOnTime"]

    /// Builds the sorted sample arrays used for ranking. Days with no activity are skipped so an
    /// idle day can't inflate today's standing.
    static func buildSamples(fromPastDays past: [DailySummary]) -> [String: [Double]] {
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

    static let scoreKey = "pawprintScore"

    static func rankings(for today: DailySummary, samples: [String: [Double]]) -> [PercentileRanking] {
        var result: [PercentileRanking] = []

        if let scoreSamples = samples[scoreKey], let score = today.score, score.total > 0 {
            result.append(ranking(
                metricID: scoreKey,
                title: "오늘의 점수",
                icon: "star.fill",
                todayValue: Double(score.total),
                display: "\(score.total)점",
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
    static func headline(for ranking: PercentileRanking) -> String {
        guard ranking.totalDays >= 3 else {
            return "기록이 조금 더 쌓이면 순위를 보여드릴게요"
        }
        switch ranking.topPercent {
        case ...5: return "지금까지 중 손에 꼽히는 하루예요"
        case 6...15: return "평소보다 훨씬 바쁜 하루예요"
        case 16...35: return "제법 바쁜 하루예요"
        case 36...65: return "평소와 비슷한 하루예요"
        case 66...85: return "여유로운 하루예요"
        default: return "조용한 하루예요"
        }
    }
}
