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
            VStack(alignment: .leading, spacing: 6) {
                header(L10n.t("achievements.hidden"),
                       L10n.t("achievements.hidden.caption"),
                       "\(hiddenFound) / \(AchievementID.hidden.count)")
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(AchievementID.hidden) { id in
                        slot(id, unlockedOn: achievements.unlockedRecord(id)?.unlockedOn)
                    }
                }
                // Grid cells are too narrow for the condition text, so found ones explain
                // themselves underneath. Locked ones say nothing — that is the point.
                ForEach(AchievementID.hidden.filter { achievements.isUnlocked($0) }) { id in
                    conditionRow(id)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                header(L10n.t("achievements.open"),
                       L10n.t("achievements.open.caption"),
                       "\(AchievementID.open.filter { achievements.isUnlocked($0) }.count) / \(AchievementID.open.count)")
                // Rows, not a grid: the whole question about these is *when do they fire*, and a
                // three-column badge has nowhere to say so. It used to be tooltip-only.
                VStack(spacing: 0) {
                    ForEach(Array(AchievementID.open.enumerated()), id: \.element) { index, id in
                        if index > 0 { Divider().opacity(0.3) }
                        openRow(id)
                    }
                }
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.045)))
            }
        }
        .padding(14)
    }

    private func header(_ title: String, _ caption: String, _ progress: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
        }
    }

    /// What a hidden achievement turned out to require, shown once it has been found.
    private func conditionRow(_ id: AchievementID) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(id.emoji).font(.system(size: 11))
            Text(id.title).font(.system(size: 10, weight: .semibold))
            Text(id.detail)
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func openRow(_ id: AchievementID) -> some View {
        let unlockedOn = achievements.unlockedRecord(id)?.unlockedOn
        return HStack(alignment: .center, spacing: 8) {
            Text(id.emoji)
                .font(.system(size: 17))
                .grayscale(unlockedOn == nil ? 1 : 0)
                .opacity(unlockedOn == nil ? 0.4 : 1)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(id.title)
                    .font(.system(size: 11, weight: unlockedOn == nil ? .regular : .semibold))
                    .foregroundStyle(unlockedOn == nil ? .secondary : .primary)
                Text(id.detail)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let unlockedOn {
                Text(Formatters.shortDayLabel(unlockedOn))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 6)
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
