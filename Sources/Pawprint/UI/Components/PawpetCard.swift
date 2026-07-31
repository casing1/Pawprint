import SwiftUI
import PawprintCore

/// The day's cat plus a plain-language reading of what it's showing.
///
/// The drawing is only worth having if you can tell *why* it looks the way it does, so every
/// visible trait gets a line naming the metric behind it. Three are shown by default; the rest are
/// one click away.
@MainActor
struct PawpetCard: View {
    let summary: DailySummary
    var streakDays: Int = 0

    /// How wide the trait labels need to be in whatever language is loaded.
    ///
    /// Measured rather than guessed: the fixed 26 points this replaced fitted Korean's two-
    /// character names and split "Expression" across three lines in English.
    static func labelColumnWidth(_ labels: [String]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
        let widest = labels
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 26
        // Capped so one unusually long name cannot squeeze the reasons into a ribbon.
        return min(72, ceil(widest) + 1)
    }

    /// Screenshot capture can start it open; a captured window has no pointer to click with.
    @State private var showAllNotes = DebugEnvironment.expandsCatNotes

    var body: some View {
        let pet = PawpetView(
            summary: summary,
            size: 108,
            streakDays: streakDays
        )
        let traits = pet.traits
        let notes = traits.notes
        let visible = showAllNotes ? notes : Array(notes.prefix(3))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                pet
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(L10n.t("pawpetCard.be3bfdb0")).font(.caption).foregroundStyle(.secondary)
                        InfoBadge(
                            title: L10n.t("pawpetCard.be3bfdb0"),
                            explanation: L10n.t("pawpetCard.ef03744e"),
                            detail: L10n.t("pawpetCard.a2e3e955", Formatters.groupedNumber(PawpetTraits.combinationCount))
                        )
                        Spacer()
                    }
                    Text(traits.caption).font(.callout.weight(.semibold))
                    // Plain rows with a measured label column, not a Grid.
                    //
                    // A Grid sizes its columns to the widest cell, which is exactly what was wanted
                    // — but a cell that grows vertically inside one (`fixedSize(vertical:)` on a
                    // wrapping reason) is measured at a width the row does not end up having, so
                    // expanding the card pushed the last notes out through the bottom of it and
                    // left the collapse button beside them. Measuring the labels directly gives the
                    // same alignment with a layout that cannot disagree with itself.
                    let labelWidth = Self.labelColumnWidth(visible.map(\.trait))
                    ForEach(visible, id: \.trait) { note in
                        HStack(alignment: .top, spacing: 5) {
                            Text(note.trait)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: labelWidth, alignment: .leading)
                            Text(note.reason)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if notes.count > 3 {
                Button(showAllNotes ? L10n.t("pawpetCard.0d2c2495") : L10n.t("pawpetCard.db8825e0", notes.count - 3)) {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllNotes.toggle() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }
}
