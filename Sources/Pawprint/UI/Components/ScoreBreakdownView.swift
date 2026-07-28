import SwiftUI

/// Shows how today's score was arrived at.
///
/// The card itself gives four unlabelled bars and a total, which is enough to see *that* the parts
/// differ and nothing about why. This lists each part with the figure it measured, the figure at
/// which it stops adding more, and the points that produced — so the total can be checked rather
/// than taken on trust.
@MainActor
struct ScoreBreakdownView: View {
    let score: PawprintScore
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("score.breakdown.title")).font(.headline)
                    Text(L10n.t("score.breakdown.subtitle", score.total, score.grade))
                        .font(.caption).foregroundStyle(.secondary)
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
        .frame(width: 380, height: 420)
    }

    /// Split out so verification can snapshot it: `ImageRenderer` draws a `ScrollView` empty.
    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(score.components.enumerated()), id: \.element.id) { index, part in
                    if index > 0 { Divider().opacity(0.3) }
                    row(part)
                }
            }
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.05)))

            HStack {
                Text(L10n.t("score.breakdown.total")).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(score.total) / 100")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 10)

            Text(L10n.t("score.breakdown.curve"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.t("score.breakdown.grades"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.t("score.breakdown.note"))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }

    private func row(_ part: PawprintScore.Component) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(part.label).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(part.earned) / \(part.maximum)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
            Text(L10n.t("score.breakdown.measured", part.measured, part.reference))
                .font(.system(size: 10)).foregroundStyle(.secondary)
            // A bar of the part's own share of 100, so the four are comparable at a glance —
            // 20 out of 20 and 20 out of 30 are not the same contribution.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.65))
                        .frame(width: part.maximum > 0
                               ? geo.size.width * Double(part.earned) / Double(part.maximum)
                               : 0)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 8)
    }
}
