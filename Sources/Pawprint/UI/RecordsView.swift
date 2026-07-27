import SwiftUI

struct RecordsView: View {
    @Bindable var activityCenter = ActivityCenter.shared
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
                label: "누적 기록 카드",
                suggestedFileName: "pawprint_lifetime.png"
            )

            QuestList(overall: activityCenter.overallLevel, quests: activityCenter.quests)

            lifetimeTotals

            WeeklySummaryCard(rollup: weeklyRollup)

            if allSummaries.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("개인 최고 기록").font(.caption).foregroundStyle(.secondary)
                    if let day = stats.bestWPMDay, stats.bestWPM > 0 {
                        recordRow(icon: "bolt.fill", title: "최고 타자 속도",
                                  value: Formatters.wpm(stats.bestWPM),
                                  exact: String(format: "%.1f WPM", stats.bestWPM), day: day)
                    }
                    if let day = stats.bestKeysDay, stats.bestKeysInDay > 0 {
                        recordRow(icon: "keyboard", title: "하루 최대 키 입력",
                                  value: Formatters.compactNumber(stats.bestKeysInDay),
                                  exact: Formatters.exactNumber(stats.bestKeysInDay), day: day)
                    }
                    if let day = stats.bestFocusDay, stats.bestFocusSeconds > 0 {
                        recordRow(icon: "target", title: "최장 집중",
                                  value: Formatters.compactDuration(stats.bestFocusSeconds),
                                  exact: Formatters.exactDuration(stats.bestFocusSeconds), day: day)
                    }
                    if let day = stats.bestActiveDay, stats.bestActiveSeconds > 0 {
                        recordRow(icon: "clock.fill", title: "하루 최대 사용시간",
                                  value: Formatters.compactDuration(stats.bestActiveSeconds),
                                  exact: Formatters.exactDuration(stats.bestActiveSeconds), day: day)
                    }
                    if let day = stats.bestScoreDay, stats.bestScoreTotal > 0 {
                        recordRow(icon: "star.fill", title: "최고 점수", value: "\(stats.bestScoreTotal)점", day: day)
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
                            Text("\(WrappedReport.monthTitle(for: month)) 돌아보기")
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
                        Text("아직 돌아볼 기록이 부족해요")
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
            Text("전체 누적").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                totalTile("총 키 입력", Formatters.compactNumber(stats.totalKeyPresses), "keyboard",
                          exact: Formatters.exactNumber(stats.totalKeyPresses))
                totalTile("총 클릭", Formatters.compactNumber(stats.totalClicks), "cursorarrow.click",
                          exact: Formatters.exactNumber(stats.totalClicks))
                totalTile("커서 총 이동", Formatters.compactDistance(meters: stats.cursorDistanceMeters), "figure.run",
                          exact: Formatters.exactNumber(Int(stats.cursorDistanceMeters)) + "m")
                totalTile("총 스크롤", Formatters.compactNumber(Int(stats.scrollScreens)) + "화면", "scroll",
                          exact: Formatters.exactNumber(Int(stats.scrollScreens)) + "화면")
                totalTile("총 사용시간", Formatters.longSpan(stats.totalActiveSeconds), "clock",
                          exact: Formatters.exactDuration(stats.totalActiveSeconds))
                totalTile("총 화면 켜짐", Formatters.longSpan(stats.totalScreenOnSeconds), "display",
                          exact: Formatters.exactDuration(stats.totalScreenOnSeconds))
                totalTile("총 집중시간", Formatters.longSpan(stats.totalFocusSeconds), "target",
                          exact: Formatters.exactDuration(stats.totalFocusSeconds))
                totalTile("기록한 날", "\(stats.daysRecorded)일", "calendar")
                totalTile("총 다운로드", Formatters.bytes(stats.networkDownloadBytes), "arrow.down.circle")
                totalTile("총 업로드", Formatters.bytes(stats.networkUploadBytes), "arrow.up.circle")
            }

            if let weekday = stats.busiestWeekday {
                Text("가장 바쁜 요일은 \(Formatters.weekdayName(weekday))요일이에요")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            if let wh = stats.totalEnergyWattHours, wh > 0 {
                Text(String(format: "지금까지 배터리로 약 %.0fWh를 썼어요", wh))
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
                Text("연속 사용").font(.caption).foregroundStyle(.secondary)
                Text("\(activityCenter.currentStreak)일째").font(.headline)
            }
            Spacer()
            Text("쉬는 날도 괜찮아요")
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
