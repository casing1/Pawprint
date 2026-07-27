import SwiftUI

/// The collection of every cat you've had.
///
/// A cat that exists only on the day it's generated is decoration. Kept, scored and sortable, it
/// becomes a record — you can find your rarest day, or the week you wore the gold frame every day.
/// Nothing extra is stored: each cat is a pure function of its day's summary, so the gallery is
/// built by re-deriving traits from history already in the database.
struct PawpetGalleryView: View {
    @Bindable var activityCenter = ActivityCenter.shared

    @State private var days: [DailySummary] = []
    @State private var selected: DailySummary?
    @State private var filter: Filter = .all
    @State private var sort: SortField = .rarity
    @State private var descending = true

    /// Ways to narrow the collection. Rarity filters answer "which days did I actually earn
    /// something"; the grade filter answers "show me only the good ones".
    enum Filter: String, CaseIterable, Identifiable {
        case all, legendary, framed, charmed, winged
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "전체"
            case .legendary: return "S·A급"
            case .framed: return "액자"
            case .charmed: return "장식"
            case .winged: return "날개"
            }
        }
    }

    enum SortField: String, CaseIterable, Identifiable {
        case rarity, date, score
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rarity: return "희귀도"
            case .date: return "날짜"
            case .score: return "점수"
            }
        }
    }

    private var dayStartHour: Int { activityCenter.settings.dayStartHour }

    /// Streak only applies to today — historical streak values aren't stored, so past cats are
    /// drawn without a collar rather than with a wrong one.
    private func streak(for summary: DailySummary) -> Int {
        summary.day == activityCenter.todaySummary.day ? activityCenter.currentStreak : 0
    }

    private func traits(for summary: DailySummary) -> PawpetTraits {
        PawpetTraits(day: summary.day, summary: summary, streakDays: streak(for: summary))
    }

    private func matches(_ summary: DailySummary, _ option: Filter) -> Bool {
        let t = traits(for: summary)
        switch option {
        case .all: return true
        case .legendary: return t.rarityGrade == "S" || t.rarityGrade == "A"
        case .framed: return t.frame != .none
        case .charmed: return t.pawCharm != .none
        case .winged: return t.wings != .none
        }
    }

    private var visible: [DailySummary] {
        let subset = days.filter { matches($0, filter) }
        return subset.sorted { lhs, rhs in
            let ascending: Bool
            switch sort {
            case .rarity:
                let a = traits(for: lhs).rarity
                let b = traits(for: rhs).rarity
                // Ties fall back to date so the order is stable and never looks shuffled.
                ascending = a == b ? lhs.day < rhs.day : a < b
            case .date:
                ascending = lhs.day < rhs.day
            case .score:
                let a = lhs.score?.total ?? 0
                let b = rhs.score?.total ?? 0
                ascending = a == b ? lhs.day < rhs.day : a < b
            }
            return descending ? !ascending : ascending
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryStrip
            filterChips
            sortBar

            if visible.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(visible, id: \.day) { summary in
                        cell(summary)
                    }
                }
            }
        }
        .padding(14)
        .onAppear(perform: load)
        .sheet(item: $selected) { summary in
            PawpetDetailView(summary: summary, streakDays: streak(for: summary)) { selected = nil }
        }
    }

    // MARK: - Pieces

    private var summaryStrip: some View {
        let best = days.map { traits(for: $0).rarity }.max() ?? 0
        let legendary = days.filter { traits(for: $0).rarityGrade == "S" }.count
        let average = days.isEmpty ? 0 : days.map { traits(for: $0).rarity }.reduce(0, +) / days.count
        return HStack(spacing: 8) {
            stat("모은 고양이", "\(days.count)마리")
            stat("최고 희귀도", "\(best)")
            stat("S급", "\(legendary)마리")
            stat("평균 희귀도", "\(average)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary.opacity(0.4)))
    }

    /// Plain chips rather than a segmented `Picker`: they carry the per-filter count, which is
    /// the whole point of a rarity filter.
    private var filterChips: some View {
        HStack(spacing: 5) {
            ForEach(Filter.allCases) { option in
                let count = days.filter { matches($0, option) }.count
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { filter = option }
                } label: {
                    HStack(spacing: 3) {
                        Text(option.label).font(.system(size: 10, weight: .medium))
                        Text("\(count)")
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(filter == option ? .white.opacity(0.8) : .secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(filter == option ? Color.accentColor : Color.secondary.opacity(0.15))
                    )
                    .foregroundStyle(filter == option ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var sortBar: some View {
        HStack(spacing: 5) {
            Text("정렬").font(.system(size: 9)).foregroundStyle(.tertiary)
            ForEach(SortField.allCases) { field in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Tapping the active field flips direction — the usual table-header idiom.
                        if sort == field { descending.toggle() } else { sort = field }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(field.label).font(.system(size: 10, weight: .medium))
                        if sort == field {
                            Image(systemName: descending ? "arrow.down" : "arrow.up")
                                .font(.system(size: 7, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().stroke(sort == field ? Color.accentColor : Color.secondary.opacity(0.3),
                                         lineWidth: 1)
                    )
                    .foregroundStyle(sort == field ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Text(descending ? "높은 순" : "낮은 순")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🐾").font(.largeTitle)
            Text(filter == .all ? "아직 모은 고양이가 없어요" : "이 조건에 맞는 고양이가 아직 없어요")
                .font(.caption).foregroundStyle(.secondary)
            if filter != .all {
                Text("기록이 쌓이면 액자와 장식이 붙기 시작해요")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func cell(_ summary: DailySummary) -> some View {
        let t = traits(for: summary)
        return Button {
            selected = summary
        } label: {
            VStack(spacing: 2) {
                PawpetView(summary: summary, size: 62, streakDays: streak(for: summary), showsAura: true)
                    .overlay(alignment: .topLeading) {
                        Text(t.rarityGrade)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Capsule().fill(t.rarityColor))
                            .padding(2)
                    }
                HStack(spacing: 3) {
                    Text(Formatters.shortDayLabel(summary.day))
                        .font(.system(size: 8)).foregroundStyle(.secondary)
                    Text("\(t.rarity)")
                        .font(.system(size: 8, weight: .semibold).monospacedDigit())
                        .foregroundStyle(t.rarityColor)
                }
                .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("\(Formatters.dayLabel(summary.day)) · \(t.rarityLabel) \(t.rarity) · \(t.caption)")
    }

    private func load() {
        let raws = PawprintStore.shared.allDays()
        var result = raws.map { SummaryCache.shared.summary(for: $0, dayStartHour: dayStartHour) }
        let todayKey = activityCenter.todaySummary.day
        result.removeAll { $0.day == todayKey }
        result.insert(activityCenter.todaySummary, at: 0)
        days = result
    }
}

/// One cat, big, with its rarity breakdown, the day's numbers, and why every trait looks that way.
struct PawpetDetailView: View {
    let summary: DailySummary
    var streakDays: Int = 0
    var onClose: () -> Void

    private var traits: PawpetTraits {
        PawpetTraits(day: summary.day, summary: summary, streakDays: streakDays)
    }

    var body: some View {
        let t = traits
        VStack(spacing: 0) {
            header(t)
            Divider()
            ScrollView { content }
        }
        .frame(width: 400, height: 560)
    }

    /// Exposed rather than inlined so it can be rendered on its own: `ImageRenderer` produces an
    /// empty page for `ScrollView` contents, which would hide any layout regression here.
    var content: some View {
        let t = traits
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PawpetView(summary: summary, size: 150, streakDays: streakDays)
                rarityPanel(t)
            }
            breakdownSection(t)
            statsSection
            notesSection(t)
        }
        .padding(16)
    }

    private func header(_ t: PawpetTraits) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(Formatters.dayLabel(summary.day)).font(.headline)
                Text(t.caption).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { onClose() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private func rarityPanel(_ t: PawpetTraits) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(t.rarityGrade)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(t.rarityColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.rarityLabel).font(.callout.weight(.semibold))
                    Text("희귀도 \(t.rarity) / 100")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(t.rarityColor)
                        .frame(width: max(3, geo.size.width * CGFloat(t.rarity) / 100))
                }
            }
            .frame(height: 6)

            Text("\(PawpetTraits.palettes[t.paletteIndex].name)색 \(t.patternName)")
                .font(.caption2).foregroundStyle(.secondary)
            Text("\(PawpetTraits.eyeColors[t.eyeColorIndex].name)빛 눈 · 수염 \(t.whiskers)쌍")
                .font(.caption2).foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }

    private func breakdownSection(_ t: PawpetTraits) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text("희귀도 구성").font(.caption).foregroundStyle(.secondary)
                InfoBadge(
                    title: "희귀도",
                    explanation: "얻기 어려운 요소일수록 높은 점수예요. 액자·발 장식·날개·배경이 80점, 목걸이·머리·표정·주변 효과가 20점을 차지해요.",
                    detail: "털색과 무늬는 날짜로 무작위 결정되니 점수에 넣지 않아요 — 노력으로 바꿀 수 없는 값이니까요."
                )
                Spacer()
            }
            ForEach(t.rarityBreakdown, id: \.label) { row in
                HStack(spacing: 6) {
                    Text(row.label)
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 42, alignment: .leading)
                    Text(row.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(row.earned > 0 ? Color.secondary : Color.secondary.opacity(0.5))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule()
                                .fill(row.earned > 0 ? t.rarityColor.opacity(0.85) : Color.clear)
                                .frame(width: geo.size.width * CGFloat(row.earned / row.maximum))
                        }
                    }
                    .frame(width: 60, height: 5)
                    Text("\(Int(row.earned))/\(Int(row.maximum))")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    /// The day's actual numbers, driven by the metric catalog so new metrics appear here too.
    private var statsSection: some View {
        let metrics = MetricCatalog.all.filter { $0.availableAsCard }.prefix(8)
        return VStack(alignment: .leading, spacing: 5) {
            Text("그날의 기록").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(Array(metrics)) { metric in
                    HStack(spacing: 5) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 13)
                        Text(metric.title).font(.system(size: 9)).foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text(metric.display(summary))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.quaternary.opacity(0.35)))
                }
            }
            if let score = summary.score {
                Text("그날의 점수 \(score.total)점 (\(score.grade)등급) — 액자 등급을 결정해요")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func notesSection(_ t: PawpetTraits) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("왜 이렇게 생겼나요").font(.caption).foregroundStyle(.secondary)
            ForEach(t.notes, id: \.trait) { note in
                HStack(alignment: .top, spacing: 6) {
                    Text(note.trait)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .leading)
                    Text(note.reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
