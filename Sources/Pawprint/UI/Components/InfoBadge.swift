import SwiftUI

/// Small "ⓘ" affordance that reveals an explanation on click. Used anywhere the app shows a
/// number whose meaning isn't self-evident — the playful indices especially, where the user
/// deserves to know exactly what went into a score before reading anything into it.
struct InfoBadge: View {
    let title: String
    let explanation: String
    var detail: String? = nil

    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.bold))
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Divider()
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}

/// Canonical descriptions of the derived indices, kept in one place so the popover text and any
/// future copy can't drift apart.
enum MetricExplanations {
    static let regret = (
        title: L10n.t("infoBadge.d32aef3b"),
        body: L10n.t("infoBadge.3ac264d8"),
        detail: L10n.t("infoBadge.c5e70d8c")
    )

    static let chaos = (
        title: L10n.t("infoBadge.8d82b6ef"),
        body: L10n.t("infoBadge.67ad806d"),
        detail: L10n.t("infoBadge.379e7d58")
    )

    static let score = (
        title: L10n.t("infoBadge.c0849f0a"),
        body: L10n.t("infoBadge.ccaddf17"),
        detail: L10n.t("infoBadge.dfcc74df")
    )

    static let persona = (
        title: L10n.t("infoBadge.64ee2fc5"),
        body: L10n.t("infoBadge.6783ea14"),
        detail: L10n.t("infoBadge.5bb0c341")
    )

    static let focus = (
        title: L10n.t("infoBadge.dcb92d2f"),
        body: L10n.t("infoBadge.bc617bb0"),
        detail: L10n.t("infoBadge.487b65e7")
    )

    static let screenTime = (
        title: L10n.t("infoBadge.e5e7450c"),
        body: L10n.t("infoBadge.060f778c"),
        detail: L10n.t("infoBadge.53e3ef50")
    )

    static let network = (
        title: L10n.t("infoBadge.d182eb6a"),
        body: L10n.t("infoBadge.9283801c"),
        detail: L10n.t("infoBadge.5f783ec6")
    )

    static let keyboardHeatmap = (
        title: L10n.t("infoBadge.d0bd899a"),
        body: L10n.t("infoBadge.d5b39aee"),
        detail: L10n.t("infoBadge.89e7602a")
    )

    static let appConcentration = (
        title: L10n.t("infoBadge.c8d17c79"),
        body: L10n.t("infoBadge.97ccf128"),
        detail: L10n.t("infoBadge.894f8154")
    )

    static let energy = (
        title: L10n.t("infoBadge.1ba83489"),
        body: L10n.t("infoBadge.176f76b7"),
        detail: L10n.t("infoBadge.5f0c365d")
    )

    static let level = (
        title: L10n.t("infoBadge.243c18f1"),
        body: L10n.t("infoBadge.16b08d2b"),
        detail: L10n.t("infoBadge.018ff480")
    )
}
