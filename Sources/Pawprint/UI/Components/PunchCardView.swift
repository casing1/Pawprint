import SwiftUI

/// Weekday × hour heatmap of all recorded activity — the "punch card" GitHub popularised.
///
/// The daily views answer "what did I do today"; this answers "what does my week actually look
/// like", which only becomes visible once history accumulates. Built entirely from the existing
/// per-minute activity arrays, so it needs no new tracking.
struct PunchCardView: View {
    /// 7 × 24 grid, `[weekday][hour]`, weekday 0 = Sunday.
    let grid: [[Double]]

    private var maxValue: Double {
        grid.flatMap { $0 }.max() ?? 0
    }

    private var hasData: Bool { maxValue > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L10n.t("punchCardView.be7b4982"), systemImage: "square.grid.3x3.fill")
                    .font(.caption).foregroundStyle(.secondary)
                InfoBadge(
                    title: L10n.t("punchCardView.be7b4982"),
                    explanation: L10n.t("punchCardView.602fe1a0"),
                    detail: L10n.t("punchCardView.e2b728dd")
                )
                Spacer()
                if let peak = peakLabel {
                    Text(peak).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            if hasData {
                gridBody
                hourAxis
            } else {
                Text(L10n.t("punchCardView.7ed570a0"))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private var peakLabel: String? {
        guard hasData else { return nil }
        var best: (weekday: Int, hour: Int, value: Double) = (0, 0, 0)
        for (weekday, row) in grid.enumerated() {
            for (hour, value) in row.enumerated() where value > best.value {
                best = (weekday, hour, value)
            }
        }
        guard best.value > 0 else { return nil }
        return L10n.t("punchCardView.fe166a62", Formatters.weekdayName(best.weekday), Formatters.hourLabel(best.hour))
    }

    private var gridBody: some View {
        VStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { weekday in
                HStack(spacing: 2) {
                    Text(Formatters.weekdayName(weekday))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, alignment: .leading)
                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color(for: grid[weekday][hour]))
                            .frame(height: 11)
                            .help(L10n.t("punchCardView.fe166a62", Formatters.weekdayName(weekday), Formatters.hourLabel(hour)))
                    }
                }
            }
        }
    }

    private var hourAxis: some View {
        HStack(spacing: 2) {
            Color.clear.frame(width: 12)
            ForEach(0..<24, id: \.self) { hour in
                Group {
                    // Label every 6 hours so the axis stays readable at this width.
                    if hour % 6 == 0 {
                        Text("\(hour)")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Square-root scaling: a couple of peak hours would otherwise wash the rest of the week out.
    private func color(for value: Double) -> Color {
        guard value > 0, maxValue > 0 else { return Color.gray.opacity(0.12) }
        let intensity = (value / maxValue).squareRoot()
        return Color.accentColor.opacity(0.18 + intensity * 0.72)
    }

    /// Folds a set of days into the 7 × 24 grid.
    static func buildGrid(from summaries: [DailySummary], dayStartHour: Int) -> [[Double]] {
        var grid = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        let calendar = Calendar.current

        for summary in summaries {
            guard summary.activityPerMinute.count == 24 * 60,
                  let date = DayKey.date(fromDayString: summary.day) else { continue }
            let weekday = calendar.component(.weekday, from: date) - 1
            guard weekday >= 0, weekday < 7 else { continue }

            for (index, value) in summary.activityPerMinute.enumerated() where value > 0 {
                // Per-minute arrays are indexed from the configured day start; map back to wall clock.
                let wallMinute = (index + dayStartHour * 60) % (24 * 60)
                grid[weekday][wallMinute / 60] += Double(value)
            }
        }
        return grid
    }
}
