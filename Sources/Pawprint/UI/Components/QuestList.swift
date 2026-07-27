import SwiftUI

/// The endless-progression panel: an overall level headline plus a per-track progress list.
/// Every track always has a next threshold, so there's never a "completed everything" state.
struct QuestList: View {
    let overall: OverallLevel
    let quests: [QuestProgress]

    /// Highest-level tracks first — the ones the user has invested most in lead.
    private var sorted: [QuestProgress] {
        quests.sorted {
            $0.level != $1.level ? $0.level > $1.level : $0.fraction > $1.fraction
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            overallCard

            VStack(spacing: 6) {
                ForEach(sorted) { quest in
                    QuestRow(quest: quest)
                }
            }
        }
    }

    private var overallCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange.opacity(0.35), .yellow.opacity(0.2)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("\(overall.level)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Lv.\(overall.level) \(overall.title)")
                        .font(.callout.weight(.bold))
                    InfoBadge(
                        title: MetricExplanations.level.title,
                        explanation: MetricExplanations.level.body,
                        detail: MetricExplanations.level.detail
                    )
                }
                Text("전체 트랙 누적 레벨 \(overall.totalLevels)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct QuestRow: View {
    let quest: QuestProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(quest.track.emoji).font(.caption)
                Text(quest.displayTitle)
                    .font(.caption.weight(.medium))
                InfoBadge(
                    title: quest.track.title,
                    explanation: quest.track.explanation,
                    detail: MetricExplanations.level.body
                )
                Text("Lv.\(quest.level)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 0)
                Text(quest.track.formatted(quest.currentValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.7), Color.accentColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, geo.size.width * quest.fraction))
                }
            }
            .frame(height: 6)

            // Near the top of a level the remaining amount rounds to zero ("0분 남았어요"),
            // which reads like the bar is stuck. Say it plainly instead.
            Text(quest.fraction >= 0.98
                 ? "거의 다 왔어요!"
                 : "다음 레벨까지 \(quest.track.formatted(quest.remaining)) 남았어요")
                .font(.system(size: 9))
                .foregroundStyle(quest.fraction >= 0.98 ? Color.accentColor : Color.secondary.opacity(0.7))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }
}

/// Transient banner shown when a track levels up.
struct LevelUpBanner: View {
    let quest: QuestProgress
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(quest.track.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("레벨 업!").font(.caption.weight(.bold)).foregroundStyle(.orange)
                Text("\(quest.displayTitle) Lv.\(quest.level)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}
