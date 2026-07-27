import SwiftUI

/// The poster-style card that gets rendered to an image for sharing. Designed to be readable
/// as a standalone picture: no app chrome, high contrast, one clear headline.
///
/// Deliberately excludes app names and exact clock times — sharing a screenshot shouldn't leak
/// what the user was working in or when they were at their desk.
struct ShareCardView: View {
    enum Mode {
        case today(DailySummary)
        case lifetime(LifetimeStats, OverallLevel, [QuestProgress])
        case wrapped(WrappedReport)
    }

    let mode: Mode
    /// Which metrics to show, resolved from `MetricCatalog` by the caller. Passed in rather than
    /// read from settings inside the view so `ImageRenderer` can render it headlessly.
    var metrics: [MetricDefinition] = MetricCatalog.defaultShareIDs.compactMap { MetricCatalog.metric(id: $0) }

    static let cardWidth: CGFloat = 440

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            footer
        }
        .frame(width: Self.cardWidth)
        .background(background)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.12, blue: 0.20),
                Color(red: 0.07, green: 0.07, blue: 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("🐾")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 1) {
                Text("Pawprint")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var subtitle: String {
        switch mode {
        case .today(let s):
            return Formatters.dayLabel(s.day)
        case .lifetime(let stats, _, _):
            return L10n.t("shareCardView.92a837a4", stats.daysRecorded)
        case .wrapped(let report):
            return L10n.t("shareCardView.60145ef6", report.title, report.dayCount)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .today(let summary):
            todayContent(summary)
        case .lifetime(let stats, let overall, let quests):
            lifetimeContent(stats, overall, quests)
        case .wrapped(let report):
            wrappedContent(report)
        }
    }

    private func todayContent(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let score = summary.score {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(score.total) / 100)
                            .stroke(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: -2) {
                            Text(score.grade)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(score.total)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(score.headline)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        if let persona = summary.persona {
                            Text("\(persona.emoji) \(persona.title)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.cyan)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            statGrid(metrics.map { ($0.title, $0.display(summary)) })

            if !summary.activityTags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(summary.activityTags.prefix(3), id: \.self) { tag in
                        Text("\(tag.emoji) \(tag.label)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }

            if let fact = summary.funFacts.first {
                Text("✨ \(fact.text)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
    }

    private func lifetimeContent(_ stats: LifetimeStats, _ overall: OverallLevel, _ quests: [QuestProgress]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 0) {
                    Text("Lv.\(overall.level)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(overall.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(L10n.t("shareCardView.d64b5670", overall.totalLevels, stats.daysRecorded))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }

            // Lifetime card shows the same chosen metrics, using each one's all-time total where
            // it has one; metrics without a meaningful sum fall back to headline records.
            statGrid(lifetimeItems(stats))

            // Top three tracks by level — the ones worth bragging about.
            let top = quests.sorted { $0.level > $1.level }.prefix(3)
            if !top.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(top)) { quest in
                        Text("\(quest.track.emoji) \(quest.displayTitle) Lv.\(quest.level)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private func wrappedContent(_ report: WrappedReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("🗓")
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(report.title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(L10n.t("shareCardView.d8f0be56", report.dayCount))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
            statGrid(report.summaryItems)
        }
        .padding(.horizontal, 22)
    }

    /// All-time values for the chosen metrics, topped up with personal records so the card is
    /// never sparse when the selection has few summable metrics.
    private func lifetimeItems(_ stats: LifetimeStats) -> [(String, String)] {
        var items: [(String, String)] = metrics.compactMap { metric in
            guard let display = metric.lifetimeDisplay else { return nil }
            return (L10n.t("shareCardView.6b0aa197") + metric.title, display(stats))
        }
        let extras: [(String, String)] = [
            (L10n.t("shareCardView.99e3df8c"), stats.bestWPM > 0 ? Formatters.wpm(stats.bestWPM) : "-"),
            (L10n.t("shareCardView.67ae7b10"), Formatters.groupedNumber(stats.bestKeysInDay)),
            (L10n.t("shareCardView.068c9e05"), Formatters.compactDuration(stats.bestFocusSeconds)),
            (L10n.t("shareCardView.79df15ef"), L10n.t("shareCardView.cec3694e", stats.daysRecorded)),
        ]
        for extra in extras where items.count < AppSettings.maxShareCardMetrics {
            if !items.contains(where: { $0.0 == extra.0 }) { items.append(extra) }
        }
        return Array(items.prefix(AppSettings.maxShareCardMetrics))
    }

    private func statGrid(_ items: [(String, String)]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 12
        ) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    Text(item.1)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Pawprint for macOS")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Text(L10n.t("shareCardView.5d13df42"))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}
