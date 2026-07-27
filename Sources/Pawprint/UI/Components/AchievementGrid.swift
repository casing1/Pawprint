import SwiftUI

struct AchievementGrid: View {
    @Bindable var achievements = AchievementEngine.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("업적").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(achievements.unlocked.count) / \(AchievementID.allCases.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AchievementID.allCases) { id in
                    AchievementBadge(
                        id: id,
                        unlockedOn: achievements.unlockedRecord(id)?.unlockedOn
                    )
                }
            }
        }
    }
}

private struct AchievementBadge: View {
    let id: AchievementID
    let unlockedOn: String?

    private var isUnlocked: Bool { unlockedOn != nil }

    var body: some View {
        VStack(spacing: 4) {
            Text(id.emoji)
                .font(.system(size: 22))
                .grayscale(isUnlocked ? 0 : 1)
                .opacity(isUnlocked ? 1 : 0.35)
            Text(id.title)
                .font(.caption2.weight(isUnlocked ? .semibold : .regular))
                .foregroundStyle(isUnlocked ? .primary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isUnlocked ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isUnlocked ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
        )
        .help(isUnlocked ? "\(id.detail) — \(Formatters.dayLabel(unlockedOn ?? "")) 달성" : id.detail)
    }
}

/// Brief celebration banner shown when a new achievement unlocks.
struct AchievementCelebrationBanner: View {
    let id: AchievementID
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            Text(id.emoji)
                .font(.system(size: 26))
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -25))
            VStack(alignment: .leading, spacing: 1) {
                Text("새 업적 달성!")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(id.title)
                    .font(.callout.weight(.semibold))
                Text(id.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
    }
}
