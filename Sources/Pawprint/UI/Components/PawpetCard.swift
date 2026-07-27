import SwiftUI

/// The day's cat plus a plain-language reading of what it's showing.
///
/// The drawing is only worth having if you can tell *why* it looks the way it does, so every
/// visible trait gets a line naming the metric behind it. Three are shown by default; the rest are
/// one click away.
struct PawpetCard: View {
    let summary: DailySummary
    var streakDays: Int = 0

    @State private var showAllNotes = false

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
                    ForEach(visible, id: \.trait) { note in
                        HStack(alignment: .top, spacing: 4) {
                            Text(note.trait)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 26, alignment: .leading)
                            Text(note.reason)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
