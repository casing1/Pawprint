import SwiftUI

struct WeeklySummaryCard: View {
    let rollup: WeeklyRollup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("이번 주", systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let delta = rollup.activeTimeDeltaPercent, abs(delta) >= 5 {
                    HStack(spacing: 2) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(Int(abs(delta)))%")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(delta > 0 ? .orange : .blue)
                    .help("지난주 활성 사용시간 대비")
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    metric("활성 사용", Formatters.compactDuration(rollup.totalActiveSeconds))
                    metric("키 입력", Formatters.groupedNumber(rollup.totalKeyPresses))
                }
                GridRow {
                    metric("집중시간", Formatters.compactDuration(rollup.totalFocusSeconds))
                    metric("최고 속도", rollup.maxWPM > 0 ? Formatters.wpm(rollup.maxWPM) : "-")
                }
            }

            if let tag = rollup.dominantTag {
                Text("이번 주 대표 유형: \(tag.emoji) \(tag.label)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let busiest = rollup.busiestWeekday {
                Text("가장 활동량이 높았던 날: \(WeeklyRollup.weekdayName(busiest))")
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
