import SwiftUI
import PawprintCore

@MainActor
struct RecordsView: View {
    @Environment(ActivityCenter.self) private var activityCenter
    /// Loaded once per tab appearance (cached across visits by `SummaryCache`).
    @State private var pastSummaries: [DailySummary] = []
    @State private var presentedMonth: WrappedMonth?

    private var allSummaries: [DailySummary] {
        pastSummaries + [activityCenter.todaySummary]
    }

    private var stats: LifetimeStats { activityCenter.lifetimeStats }

    private func loadPastSummaries() {
        let todayKey = activityCenter.todaySummary.day
        let dayStartHour = activityCenter.settings.dayStartHour
        pastSummaries = PawprintStore.shared.allDays()
            .filter { $0.day != todayKey }
            .map { SummaryCache.shared.summary(for: $0, dayStartHour: dayStartHour) }
        activityCenter.refreshLifetimeStats(force: true)
    }

    private var weeklyRollup: WeeklyRollup {
        let calendar = Calendar.current
        let todayKey = activityCenter.todaySummary.day
        guard let todayDate = DayKey.date(fromDayString: todayKey) else { return WeeklyRollup() }
        let weekday = calendar.component(.weekday, from: todayDate)
        let thisWeekStart = DayKey.addingDays(-(weekday - 1), to: todayKey)
        let lastWeekStart = DayKey.addingDays(-7, to: thisWeekStart)

        let thisWeek = allSummaries.filter { $0.day >= thisWeekStart && $0.day <= todayKey }
        let lastWeek = allSummaries.filter { $0.day >= lastWeekStart && $0.day < thisWeekStart }
        return WeeklyRollup.build(thisWeek: thisWeek, lastWeek: lastWeek)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let levelUp = activityCenter.pendingLevelUp {
                LevelUpBanner(quest: levelUp) { activityCenter.clearLevelUp() }
                    .overlay(ConfettiView(particleCount: 30, duration: 1.8))
            }

            wrappedEntry

            streakCard

            ShareButton(
                mode: .lifetime(stats, activityCenter.overallLevel, activityCenter.quests),
                label: L10n.t("recordsView.68c66928"),
                suggestedFileName: "pawprint_lifetime.png"
            )

            QuestList(overall: activityCenter.overallLevel, quests: activityCenter.quests)

            lifetimeTotals

            WeeklySummaryCard(rollup: weeklyRollup)

            if allSummaries.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("recordsView.59f6bdb4")).font(.caption).foregroundStyle(.secondary)
                    if let day = stats.bestWPMDay, stats.bestWPM > 0 {
                        recordRow(icon: "bolt.fill", title: L10n.t("recordsView.99e3df8c"),
                                  value: Formatters.wpm(stats.bestWPM),
                                  exact: String(format: "%.1f WPM", stats.bestWPM), day: day)
                    }
                    if let day = stats.bestKeysDay, stats.bestKeysInDay > 0 {
                        recordRow(icon: "keyboard", title: L10n.t("recordsView.a82546d5"),
                                  value: Formatters.compactNumber(stats.bestKeysInDay),
                                  exact: Formatters.exactNumber(stats.bestKeysInDay), day: day)
                    }
                    if let day = stats.bestFocusDay, stats.bestFocusSeconds > 0 {
                        recordRow(icon: "target", title: L10n.t("recordsView.068c9e05"),
                                  value: Formatters.compactDuration(stats.bestFocusSeconds),
                                  exact: Formatters.exactDuration(stats.bestFocusSeconds), day: day)
                    }
                    if let day = stats.bestActiveDay, stats.bestActiveSeconds > 0 {
                        recordRow(icon: "clock.fill", title: L10n.t("recordsView.3d3eb474"),
                                  value: Formatters.compactDuration(stats.bestActiveSeconds),
                                  exact: Formatters.exactDuration(stats.bestActiveSeconds), day: day)
                    }
                    if let day = stats.bestScoreDay, stats.bestScoreTotal > 0 {
                        recordRow(icon: "star.fill", title: L10n.t("recordsView.dc2b17b1"), value: L10n.t("recordsView.f0b5b795", stats.bestScoreTotal), day: day)
                    }
                }
            }
        }
        .padding(14)
        .onAppear { loadPastSummaries() }
    }

    /// Entry point for the month retrospective. Only offered for months with enough days that a
    /// retrospective is worth watching.
    private var wrappedEntry: some View {
        Group {
            if let month = availableWrappedMonths.first {
                Button {
                    presentedMonth = WrappedMonth(id: month)
                } label: {
                    HStack(spacing: 10) {
                        Text("🗓").font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.t("recordsView.24352f0e", WrappedReport.monthTitle(for: month)))
                                .font(.callout.weight(.semibold))
                            Text("Pawprint Wrapped")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [Color.purple.opacity(0.18), Color.cyan.opacity(0.12)],
                                                 startPoint: .leading, endPoint: .trailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .sheet(item: $presentedMonth) { month in
                    if let report = WrappedReport.build(
                        monthKey: month.id,
                        summaries: allSummaries,
                        previousMonth: allSummaries.filter { $0.day.hasPrefix(WrappedMonth.previousKey(of: month.id)) }
                    ) {
                        WrappedView(report: report) { presentedMonth = nil }
                    } else {
                        Text(L10n.t("recordsView.fa2fd0cc"))
                            .font(.callout).padding(30)
                    }
                }
            }
        }
    }

    private var availableWrappedMonths: [String] {
        WrappedReport.availableMonths(from: allSummaries)
    }

    private var lifetimeTotals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("recordsView.7a810d6d")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                totalTile(L10n.t("recordsView.110bf3ae"), Formatters.compactNumber(stats.totalKeyPresses), "keyboard",
                          exact: Formatters.exactNumber(stats.totalKeyPresses))
                totalTile(L10n.t("recordsView.866e0ee4"), Formatters.compactNumber(stats.totalClicks), "cursorarrow.click",
                          exact: Formatters.exactNumber(stats.totalClicks))
                totalTile(L10n.t("recordsView.4a489ead"), Formatters.compactDistance(meters: stats.cursorDistanceMeters), "figure.run",
                          exact: Formatters.exactNumber(Int(stats.cursorDistanceMeters)) + "m")
                totalTile(L10n.t("recordsView.cf561eea"), L10n.t("recordsView.5d3b8ef3", Formatters.compactNumber(Int(stats.scrollScreens))), "scroll",
                          exact: L10n.t("recordsView.5d3b8ef3", Formatters.exactNumber(Int(stats.scrollScreens))))
                totalTile(L10n.t("recordsView.49d8f80b"), Formatters.longSpan(stats.totalActiveSeconds), "clock",
                          exact: Formatters.exactDuration(stats.totalActiveSeconds))
                totalTile(L10n.t("recordsView.0c36eb4f"), Formatters.longSpan(stats.totalScreenOnSeconds), "display",
                          exact: Formatters.exactDuration(stats.totalScreenOnSeconds))
                totalTile(L10n.t("recordsView.da8dd921"), Formatters.longSpan(stats.totalFocusSeconds), "target",
                          exact: Formatters.exactDuration(stats.totalFocusSeconds))
                totalTile(L10n.t("recordsView.79df15ef"), L10n.t("recordsView.cec3694e", stats.daysRecorded), "calendar")
                totalTile(L10n.t("recordsView.55607b29"), Formatters.bytes(stats.networkDownloadBytes), "arrow.down.circle")
                totalTile(L10n.t("recordsView.02d402ef"), Formatters.bytes(stats.networkUploadBytes), "arrow.up.circle")
            }

            if let weekday = stats.busiestWeekday {
                Text(L10n.t("recordsView.7eddd220", Formatters.weekdayName(weekday)))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            if let wh = stats.totalEnergyWattHours, wh > 0 {
                Text(String(format: L10n.t("recordsView.c61a62b5"), wh))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func totalTile(_ title: String, _ value: String, _ icon: String, exact: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
                ExactValueText(compact: value, exact: exact, font: .caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }

    private var streakCard: some View {
        HStack {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("recordsView.f2f9dc78")).font(.caption).foregroundStyle(.secondary)
                Text(L10n.t("recordsView.05092309", activityCenter.currentStreak)).font(.headline)
            }
            Spacer()
            Text(L10n.t("recordsView.8ef52e73"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func recordRow(icon: String, title: String, value: String, exact: String? = nil, day: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color.accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(Formatters.dayLabel(day)).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            ExactValueText(compact: value, exact: exact)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }
}
