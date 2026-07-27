import SwiftUI

/// "How does today compare to every day I've recorded?"
///
/// A raw number ("8,432 keys") means nothing without context. Ranking today against your own
/// history turns it into an immediately legible answer — top 8% reads as "an unusually big day"
/// in a way the raw count never does.
struct PercentileCard: View {
    let rankings: [PercentileRanking]
    let headline: PercentileRanking?

    @State private var expanded = false

    private var detail: [PercentileRanking] {
        expanded ? rankings : Array(rankings.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                Label("전체 기록 중 오늘", systemImage: "chart.bar.doc.horizontal")
                    .font(.caption).foregroundStyle(.secondary)
                InfoBadge(
                    title: "전체 기록 중 오늘",
                    explanation: "지금까지 기록한 모든 날과 오늘을 비교해 순위를 매겨요. '상위 8%'는 기록된 날들 중 상위 8% 안에 든다는 뜻이에요.",
                    detail: "활동이 없던 날은 비교에서 제외해요. 기록이 10일 미만이면 백분율 대신 등수로 보여줍니다."
                )
                Spacer()
                if rankings.count > 3 {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            if let headline {
                headlineRow(headline)
            }

            VStack(spacing: 6) {
                ForEach(detail) { ranking in
                    row(ranking)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture {
            guard rankings.count > 3 else { return }
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }
    }

    private func headlineRow(_ ranking: PercentileRanking) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: -2) {
                Text(ranking.totalDays >= 10 ? "\(ranking.topPercent)%" : "\(ranking.rank)위")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint(for: ranking))
                Text(ranking.totalDays >= 10 ? "상위" : "\(ranking.totalDays)일 중")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(PercentileEngine.headline(for: ranking))
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("기록한 \(ranking.totalDays)일 중 \(ranking.rank)번째")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func row(_ ranking: PercentileRanking) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: ranking.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(ranking.isStandout ? tint(for: ranking) : Color.secondary)
                Text(ranking.title).font(.caption2)
                Spacer(minLength: 4)
                Text(ranking.displayValue)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(ranking.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ranking.isStandout ? tint(for: ranking) : Color.secondary)
            }
            // Bar fills from the right: a top-1% day fills almost completely.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(tint(for: ranking).opacity(0.75))
                        .frame(width: max(2, geo.size.width * (1 - Double(ranking.topPercent) / 100)))
                }
            }
            .frame(height: 4)
        }
    }

    private func tint(for ranking: PercentileRanking) -> Color {
        switch ranking.topPercent {
        case ...10: return .orange
        case 11...30: return .accentColor
        default: return .secondary
        }
    }
}
