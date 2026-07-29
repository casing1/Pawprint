import SwiftUI
import PawprintCore

struct WeeklySummaryCard: View {
    let rollup: WeeklyRollup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.t("weeklySummaryCard.89ea2d72"), systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let delta = rollup.activeTimeDeltaPercent, abs(delta) >= 5 {
                    HStack(spacing: 2) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(Int(abs(delta)))%")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(delta > 0 ? .orange : .blue)
                    .help(L10n.t("weeklySummaryCard.5f5e69c6"))
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    metric(L10n.t("weeklySummaryCard.0cb473d3"), Formatters.compactDuration(rollup.totalActiveSeconds))
                    metric(L10n.t("weeklySummaryCard.59ca8aa6"), Formatters.groupedNumber(rollup.totalKeyPresses))
                }
                GridRow {
                    metric(L10n.t("weeklySummaryCard.77bad0ab"), Formatters.compactDuration(rollup.totalFocusSeconds))
                    metric(L10n.t("weeklySummaryCard.50922e57"), rollup.maxWPM > 0 ? Formatters.wpm(rollup.maxWPM) : "-")
                }
            }

            if let tag = rollup.dominantTag {
                Text(L10n.t("weeklySummaryCard.1588db9c", tag.emoji, tag.label))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let busiest = rollup.busiestWeekday {
                Text(L10n.t("weeklySummaryCard.31c1cf7c", WeeklyRollup.weekdayName(busiest)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold))
        }
    }
}
