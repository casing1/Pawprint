import SwiftUI

/// The achievements sheet: nine hidden slots, plus the open ones underneath.
///
/// Hidden achievements show as an empty `?` slot until they fire. That is the whole point — their
/// conditions are shapes a day falls into rather than numbers to chase, so revealing them in
/// advance would turn a discovery into a to-do list. The count is shown, so you always know how
/// many are left, just not what they are.
///
/// Separate from the level tracks in Records: those are endless and always visible, these are
/// one-time and mostly invisible.
@MainActor
struct HiddenAchievementsView: View {
    @Bindable var achievements = AchievementEngine.shared
    var onClose: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var hiddenFound: Int {
        AchievementID.hidden.filter { achievements.isUnlocked($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("achievements.title")).font(.headline)
                    Text(L10n.t("achievements.subtitle")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
            .padding(14)
            Divider()
            ScrollView { content }
        }
        .frame(width: 430, height: 540)
    }

    /// Split out so verification can snapshot it: `ImageRenderer` draws `ScrollView` contents empty.
    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(
                title: L10n.t("achievements.hidden"),
                caption: L10n.t("achievements.hidden.caption"),
                progress: "\(hiddenFound) / \(AchievementID.hidden.count)",
                ids: AchievementID.hidden)

            section(
                title: L10n.t("achievements.open"),
                caption: L10n.t("achievements.open.caption"),
                progress: "\(AchievementID.open.filter { achievements.isUnlocked($0) }.count) / \(AchievementID.open.count)",
                ids: AchievementID.open)
        }
        .padding(14)
    }

    private func section(title: String, caption: String, progress: String, ids: [AchievementID]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(progress)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(caption)
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ids) { id in
                    slot(id, unlockedOn: achievements.unlockedRecord(id)?.unlockedOn)
                }
            }
        }
    }

    @ViewBuilder
    private func slot(_ id: AchievementID, unlockedOn: String?) -> some View {
        let isUnlocked = unlockedOn != nil
        // A locked *hidden* achievement gives nothing away — not its name, not its icon.
        let isMystery = id.isHidden && !isUnlocked

        VStack(spacing: 3) {
            if isMystery {
                Text("?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else {
                Text(id.emoji)
                    .font(.system(size: 22))
                    .grayscale(isUnlocked ? 0 : 1)
                    .opacity(isUnlocked ? 1 : 0.35)
            }

            Text(isMystery ? L10n.t("achievements.locked") : id.title)
                .font(.system(size: 10, weight: isUnlocked ? .semibold : .regular))
                .foregroundStyle(isUnlocked ? .primary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if let unlockedOn {
                Text(Formatters.shortDayLabel(unlockedOn))
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isUnlocked ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isUnlocked ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
        )
        // Mystery slots deliberately have no tooltip: a hint here would defeat the point.
        .help(isMystery ? "" : id.detail)
    }
}
