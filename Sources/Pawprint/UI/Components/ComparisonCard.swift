import SwiftUI

/// "오늘 vs 평소" — compares today against the recent average for a handful of metrics.
/// Deliberately neutral about direction: being below average is described as quieter, not worse.
struct ComparisonCard: View {
    let comparisons: [MetricComparison]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("오늘 vs 평소", systemImage: "chart.bar.xaxis")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(comparisons) { comparison in
                ComparisonRow(comparison: comparison)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }
}

struct MetricComparison: Identifiable {
    var id: String { label }
    var label: String
    var todayValue: Double
    var averageValue: Double
    var display: String
    var isRecord: Bool = false

    /// Percent change vs. the recent average; nil when there's no meaningful baseline.
    var deltaPercent: Double? {
        guard averageValue > 0 else { return nil }
        return (todayValue - averageValue) / averageValue * 100
    }

    /// Today's share of the larger of (today, average), so both bars fit a 0...1 track.
    var todayFraction: Double {
        let peak = max(todayValue, averageValue)
        guard peak > 0 else { return 0 }
        return todayValue / peak
    }

    var averageFraction: Double {
        let peak = max(todayValue, averageValue)
        guard peak > 0 else { return 0 }
        return averageValue / peak
    }
}

private struct ComparisonRow: View {
    let comparison: MetricComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(comparison.label).font(.caption)
                if comparison.isRecord {
                    Text("신기록")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange.opacity(0.25)))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(comparison.display).font(.caption.monospacedDigit().weight(.medium))
                if let delta = comparison.deltaPercent, abs(delta) >= 5 {
                    Text("\(delta > 0 ? "+" : "")\(Int(delta))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(delta > 0 ? .orange : .blue)
                }
            }

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 2) {
                    // Today
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: max(2, geo.size.width * comparison.todayFraction), height: 5)
                    // Recent average, for reference
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: max(2, geo.size.width * comparison.averageFraction), height: 3)
                }
            }
            .frame(height: 12)
        }
    }
}
