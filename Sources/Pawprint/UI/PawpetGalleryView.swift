import SwiftUI

/// The collection of every cat you've had.
///
/// A cat that exists only on the day it's generated is decoration. Kept, scored and sortable, it
/// becomes a record — you can find your rarest day, or the week you wore the gold frame every day.
/// Nothing extra is stored: each cat is a pure function of its day's summary, so the gallery is
/// built by re-deriving traits from history already in the database.
@MainActor
struct PawpetGalleryView: View {
    @Bindable var activityCenter = ActivityCenter.shared

    @State private var days: [DailySummary] = []
    @State private var selected: DailySummary?
    @State private var filter: Filter = .all
    @State private var sort: SortField = .rarity
    @State private var descending = true
    @State private var showingItemCatalog = false
    @State private var showingAchievements = false

    /// Ways to narrow the collection. Rarity filters answer "which days did I actually earn
    /// something"; the grade filter answers "show me only the good ones".
    enum Filter: String, CaseIterable, Identifiable {
        case all, legendary, framed, charmed, winged
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return L10n.t("pawpetGalleryView.934dd25e")
            case .legendary: return L10n.t("pawpetGalleryView.f90dedc0")
            case .framed: return L10n.t("pawpetGalleryView.7ad40d7f")
            case .charmed: return L10n.t("pawpetGalleryView.169ac9d5")
            case .winged: return L10n.t("pawpetGalleryView.01a400a4")
            }
        }
    }

    enum SortField: String, CaseIterable, Identifiable {
        case rarity, date, score
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rarity: return L10n.t("pawpetGalleryView.d4ebe9b6")
            case .date: return L10n.t("pawpetGalleryView.5caa75a8")
            case .score: return L10n.t("pawpetGalleryView.67d2cf6b")
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
        PawpetTraits.forDay(summary, streakDays: streak(for: summary))
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
            browseBar
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
        .sheet(isPresented: $showingItemCatalog) {
            PawpetItemCatalogView { showingItemCatalog = false }
        }
        .sheet(isPresented: $showingAchievements) {
            HiddenAchievementsView { showingAchievements = false }
        }
    }

    /// The two reference sheets. Both belong here rather than in Records: one explains how the
    /// cats are put together, the other is the one-time counterpart to the endless level tracks.
    private var browseBar: some View {
        HStack(spacing: 6) {
            browseButton(L10n.t("itemCatalog.button"), "square.grid.2x2") { showingItemCatalog = true }
            browseButton(L10n.t("achievements.button"), "rosette") { showingAchievements = true }
            Spacer(minLength: 0)
        }
    }

    private func browseButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor.opacity(0.12)))
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pieces

    private var summaryStrip: some View {
        let best = days.map { traits(for: $0).rarity }.max() ?? 0
        let legendary = days.filter { traits(for: $0).rarityGrade == "S" }.count
        let average = days.isEmpty ? 0 : days.map { traits(for: $0).rarity }.reduce(0, +) / days.count
        return HStack(spacing: 8) {
            stat(L10n.t("pawpetGalleryView.c0047d97"), L10n.t("pawpetGalleryView.31f12a97", days.count))
            stat(L10n.t("pawpetGalleryView.bae34d90"), "\(best)")
            stat(L10n.t("pawpetGalleryView.d4ed0f37"), L10n.t("pawpetGalleryView.31f12a97", legendary))
            stat(L10n.t("pawpetGalleryView.b2dc3724"), "\(average)")
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
            Text(L10n.t("pawpetGalleryView.7745cc5a")).font(.system(size: 9)).foregroundStyle(.tertiary)
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
            Text(descending ? L10n.t("pawpetGalleryView.522d7a9a") : L10n.t("pawpetGalleryView.ba68909d"))
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🐾").font(.largeTitle)
            Text(filter == .all ? L10n.t("pawpetGalleryView.8f4ea687") : L10n.t("pawpetGalleryView.daa4d86f"))
                .font(.caption).foregroundStyle(.secondary)
            if filter != .all {
                Text(L10n.t("pawpetGalleryView.e7e9605e"))
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
@MainActor
struct PawpetDetailView: View {
    let summary: DailySummary
    var streakDays: Int = 0
    var onClose: () -> Void

    private var traits: PawpetTraits {
        PawpetTraits.forDay(summary, streakDays: streakDays)
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
                    Text(L10n.t("pawpetGalleryView.67c51b91", t.rarity))
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

            Text(L10n.t("pawpetGalleryView.e8492bce", PawpetTraits.paletteName(t.paletteIndex), t.patternName))
                .font(.caption2).foregroundStyle(.secondary)
            Text(L10n.t("pawpetGalleryView.25d72384", PawpetTraits.eyeColorName(t.eyeColorIndex), t.whiskers))
                .font(.caption2).foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }

    private func breakdownSection(_ t: PawpetTraits) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(L10n.t("pawpetGalleryView.b6e2a401")).font(.caption).foregroundStyle(.secondary)
                InfoBadge(
                    title: L10n.t("pawpetGalleryView.d4ebe9b6"),
                    explanation: L10n.t("pawpetGalleryView.bd28db1a"),
                    detail: L10n.t("pawpetGalleryView.90fb2a97")
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
            Text(L10n.t("pawpetGalleryView.0ea540b7")).font(.caption).foregroundStyle(.secondary)
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
                Text(L10n.t("pawpetGalleryView.b202d32b", score.total, score.grade))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func notesSection(_ t: PawpetTraits) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t("pawpetGalleryView.e287756b")).font(.caption).foregroundStyle(.secondary)
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
