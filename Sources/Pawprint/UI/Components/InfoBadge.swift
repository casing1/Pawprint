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
