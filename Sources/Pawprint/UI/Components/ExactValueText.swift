import SwiftUI

/// A number that stays short by default but can show its full value on demand.
///
/// Abbreviation is a layout compromise, not a statement about the data — "12.3만" fits the card
/// but a record deserves its real digits. Tapping swaps to the exact form; hovering shows it as a
/// tooltip without changing anything.
///
/// `exact` is optional so callers can pass whatever raw value they actually have. When it's nil,
/// or identical to the compact form, this behaves as plain `Text` with no affordance — no dead
/// tap targets on numbers that were never abbreviated.
struct ExactValueText: View {
    let compact: String
    var exact: String?
    var font: Font = .callout.weight(.semibold)

    @State private var showingExact = false

    private var hasMore: Bool {
        guard let exact else { return false }
        return exact != compact
    }

    var body: some View {
        let shown = (showingExact && hasMore) ? (exact ?? compact) : compact
        Text(shown)
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .overlay(alignment: .bottomTrailing) {
                if hasMore && !showingExact {
                    // A dotted underline hints there's more without adding a control.
                    Rectangle()
                        .fill(Color.secondary.opacity(0.45))
                        .frame(height: 1)
                        .offset(y: 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard hasMore else { return }
                withAnimation(.easeInOut(duration: 0.2)) { showingExact.toggle() }
            }
            .help(hasMore ? (exact ?? compact) : "")
    }

    /// Convenience for plain counts, which are the ones that actually get abbreviated.
    init(count: Int, font: Font = .callout.weight(.semibold), suffix: String = "") {
        self.compact = Formatters.compactNumber(count) + suffix
        self.exact = Formatters.exactNumber(count) + suffix
        self.font = font
    }

    init(compact: String, exact: String? = nil, font: Font = .callout.weight(.semibold)) {
        self.compact = compact
        self.exact = exact
        self.font = font
    }
}
