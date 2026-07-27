import SwiftUI

/// The day's cat plus a plain-language reading of what it's showing.
///
/// The drawing is only worth having if you can tell *why* it looks the way it does, so every
/// visible trait gets a line naming the metric behind it. Three are shown by default; the rest are
/// one click away.
struct PawpetCard: View {
    let summary: DailySummary
    var streakDays: Int = 0
    var isCelebrating: Bool = false

    @State private var showAllNotes = false

    var body: some View {
        let pet = PawpetView(
            summary: summary,
            size: 108,
            streakDays: streakDays,
            isCelebrating: isCelebrating
        )
        let traits = pet.traits
        let notes = traits.notes
        let visible = showAllNotes ? notes : Array(notes.prefix(3))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                pet
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("오늘의 고양이").font(.caption).foregroundStyle(.secondary)
                        InfoBadge(
                            title: "오늘의 고양이",
                            explanation: "털색·무늬·귀·꼬리·눈색은 날짜로 정해져 하루 종일 그대로예요. 표정, 머리 장식, 안경, 소품, 목걸이, 볼, 배경, 주변 효과는 각각 다른 지표를 따라가요.",
                            detail: "나올 수 있는 조합은 \(Formatters.groupedNumber(PawpetTraits.combinationCount))가지예요."
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
                Button(showAllNotes ? "접기" : "왜 이렇게 생겼나요? (\(notes.count - 3)개 더)") {
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
