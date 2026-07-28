import SwiftUI

@MainActor
struct CalendarView: View {
    @Bindable var activityCenter = ActivityCenter.shared
    /// Selected basis, resolved from the catalog by id so a newly added metric appears here
    /// automatically. Falls back to the default if a stored id no longer exists.
    private var metric: MetricDefinition {
        MetricCatalog.metric(id: activityCenter.settings.calendarMetricID)
            ?? MetricCatalog.metric(id: MetricCatalog.defaultCalendarID)
            ?? MetricCatalog.all[0]
    }
    @State private var selectedDay: String?
    @State private var hoveredDay: String?
    /// Past days are loaded once when the tab appears (and cached across visits by
    /// `SummaryCache`) rather than recomputed as today's counters change.
    @State private var pastSummaries: [String: DailySummary] = [:]

    private let weeksToShow = 18
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3

    private var dayStartHour: Int { activityCenter.settings.dayStartHour }
    private var todayKey: String { activityCenter.todaySummary.day }

    private var gridStart: Date {
        let today = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        let backToSunday = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        return calendar.date(byAdding: .day, value: -(weeksToShow - 1) * 7, to: backToSunday) ?? backToSunday
    }

    /// Historical summaries plus a live entry for today, so the current day's cell keeps
    /// updating without dragging the whole grid through recomputation.
    private var summaries: [String: DailySummary] {
        var result = pastSummaries
        let todaySummary = activityCenter.todaySummary
        result[todaySummary.day] = todaySummary
        return result
    }

    private func loadPastSummaries() {
        let startKey = DayKey.string(for: gridStart, dayStartHour: dayStartHour)
        let raws = PawprintStore.shared.loadDays(from: startKey, to: todayKey).filter { $0.day != todayKey }
        var result: [String: DailySummary] = [:]
        for raw in raws {
            result[raw.day] = SummaryCache.shared.summary(for: raw, dayStartHour: dayStartHour)
        }
        pastSummaries = result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L10n.t("calendarView.39b300c7"), selection: activityCenter.binding(\.calendarMetricID)) {
                ForEach(MetricCatalog.enabled(MetricCatalog.calendarMetrics, settings: activityCenter.settings)) { m in
                    Text(m.title).tag(m.id)
                }
            }
            .pickerStyle(.menu)

            calendarGrid

            HStack {
                legend
                Spacer()
                Text(L10n.t("calendarView.75cfe69a", recordedDayCount))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            summaryStrip

            if let day = hoveredDay ?? selectedDay, let summary = summaries[day] {
                CalendarDayDetailCard(summary: summary, metric: metric, isBest: day == bestDayKey)
            } else {
                Text(L10n.t("calendarView.c085788d"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            }

            monthlyBreakdown

            PunchCardView(grid: punchCardGrid)
        }
        .padding(14)
        .onAppear {
            if selectedDay == nil { selectedDay = todayKey }
            loadPastSummaries()
        }
    }

    /// Weekday × hour grid over everything currently loaded.
    private var punchCardGrid: [[Double]] {
        PunchCardView.buildGrid(from: Array(summaries.values), dayStartHour: dayStartHour)
    }

    // MARK: - Derived

    private var maxValue: Double {
        summaries.values.map { metric.value($0) }.max() ?? 0
    }

    private var recordedDayCount: Int {
        summaries.values.filter { $0.activeSeconds > 0 || $0.totalKeyPresses > 0 }.count
    }

    /// The best day *for the currently selected metric*, marked with a star in the grid.
    private var bestDayKey: String? {
        summaries.max { metric.value($0.value) < metric.value($1.value) }
            .flatMap { metric.value($0.value) > 0 ? $0.key : nil }
    }

    // MARK: - Grid

    private var calendarGrid: some View {
        let calendar = Calendar.current
        return VStack(alignment: .leading, spacing: 3) {
            monthLabels(calendar: calendar)
            HStack(alignment: .top, spacing: 4) {
                weekdayLabels
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(0..<weeksToShow, id: \.self) { week in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { weekday in
                                cell(for: calendar.date(byAdding: .day, value: week * 7 + weekday, to: gridStart) ?? gridStart)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Month name placed above the first week that starts a new month.
    private func monthLabels(calendar: Calendar) -> some View {
        HStack(alignment: .bottom, spacing: cellSpacing) {
            // Spacer matching the weekday label gutter.
            Color.clear.frame(width: 16, height: 1)
            ForEach(0..<weeksToShow, id: \.self) { week in
                let date = calendar.date(byAdding: .day, value: week * 7, to: gridStart) ?? gridStart
                let previous = calendar.date(byAdding: .day, value: (week - 1) * 7, to: gridStart)
                let month = calendar.component(.month, from: date)
                let previousMonth = previous.map { calendar.component(.month, from: $0) }
                Group {
                    if week == 0 || month != previousMonth {
                        Text(L10n.t("calendarView.540792f2", month))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                            .frame(width: cellSize, alignment: .leading)
                    } else {
                        Color.clear.frame(width: cellSize, height: 8)
                    }
                }
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Group {
                    // Only label alternating rows so the gutter stays uncluttered.
                    if index % 2 == 1 {
                        Text(Formatters.weekdayInitial(index))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .help(Formatters.weekdayName(index))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 16, height: cellSize)
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let dayKey = DayKey.string(for: date, dayStartHour: dayStartHour)
        let isFuture = date > Date()
        let summary = summaries[dayKey]
        let value = summary.map { metric.value($0) } ?? 0
        let isToday = dayKey == todayKey
        let isBest = dayKey == bestDayKey && value > 0

        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(isFuture ? Color.clear : colorFor(value: value))
            if isBest {
                Image(systemName: "star.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.yellow)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(
            RoundedRectangle(cornerRadius: 2.5)
                .stroke(
                    selectedDay == dayKey ? Color.accentColor : (isToday ? Color.primary.opacity(0.55) : .clear),
                    lineWidth: selectedDay == dayKey ? 1.5 : 1
                )
        )
        .onTapGesture {
            guard !isFuture else { return }
            selectedDay = dayKey
        }
        .onHover { inside in
            guard !isFuture else { return }
            hoveredDay = inside ? dayKey : nil
        }
        .help(isFuture ? "" : tooltip(dayKey: dayKey, summary: summary))
    }

    private func tooltip(dayKey: String, summary: DailySummary?) -> String {
        guard let summary else { return L10n.t("calendarView.69920d98", Formatters.dayLabel(dayKey)) }
        return "\(Formatters.dayLabel(dayKey)) · \(metric.title) \(metric.display(summary))"
    }

    /// Formats an aggregate (sum or average) of the current metric. Individual days render via
    /// `metric.display`; aggregates have no `DailySummary` to hand it, so they reuse the metric's
    /// unit by formatting a synthetic summary is not possible — hence this narrow helper.
    private func formattedAggregate(_ value: Double) -> String {
        if metric.id.hasSuffix("Time") || metric.id == "focusTime" || metric.id == "activeTime" {
            return Formatters.compactDuration(Int(value))
        }
        if metric.id == "networkTotal" || metric.id.hasPrefix("network") {
            return Formatters.bytes(UInt64(max(0, value)))
        }
        if metric.id == "cursorDistance" {
            return value >= 1000 ? String(format: "%.1fkm", value / 1000) : String(format: "%.0fm", value)
        }
        if metric.id == "batteryUsed" { return "\(Int(value))%" }
        return Formatters.groupedNumber(Int(value.rounded()))
    }

    private func colorFor(value: Double) -> Color {
        guard maxValue > 0, value > 0 else { return .gray.opacity(0.15) }
        let ratio = value / maxValue
        return Color.accentColor.opacity(0.25 + min(ratio, 1) * 0.65)
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text(L10n.t("calendarView.0eedf854")).font(.caption2).foregroundStyle(.tertiary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level == 0 ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.25 + level * 0.65))
                    .frame(width: 10, height: 10)
            }
            Text(L10n.t("calendarView.176252ef")).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let values = summaries.values.filter { metric.value($0) > 0 }
        let total = values.reduce(0.0) { $0 + metric.value($1) }
        let average = values.isEmpty ? 0 : total / Double(values.count)
        return HStack(spacing: 8) {
            stripTile(L10n.t("calendarView.3dcb27ed"), formattedAggregate(total))
            stripTile(L10n.t("calendarView.c27998b7"), formattedAggregate(average))
            stripTile(L10n.t("calendarView.d45df3e9"), formattedAggregate(values.map { metric.value($0) }.max() ?? 0))
            stripTile(L10n.t("calendarView.86522b3c"), L10n.t("calendarView.cec3694e", activityCenter.currentStreak))
        }
    }

    private func stripTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary.opacity(0.4)))
    }

    // MARK: - Monthly breakdown

    private var monthlyBreakdown: some View {
        let calendar = Calendar.current
        var byMonth: [String: Double] = [:]
        for (day, summary) in summaries {
            guard let date = DayKey.date(fromDayString: day) else { continue }
            let key = String(format: "%04d-%02d", calendar.component(.year, from: date), calendar.component(.month, from: date))
            byMonth[key, default: 0] += metric.value(summary)
        }
        let sorted = byMonth.sorted { $0.key < $1.key }.suffix(6)
        let peak = sorted.map(\.value).max() ?? 0

        return Group {
            if sorted.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("calendarView.5763b9d2")).font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(sorted), id: \.key) { month, value in
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor.opacity(value > 0 ? 0.75 : 0.2))
                                    .frame(height: peak > 0 ? max(3, 46 * value / peak) : 3)
                                Text(Formatters.monthLabel(month))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 62, alignment: .bottom)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
            }
        }
    }
}

@MainActor
private struct CalendarDayDetailCard: View {
    let summary: DailySummary
    let metric: MetricDefinition
    let isBest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(Formatters.dayLabel(summary.day)).font(.subheadline.weight(.semibold))
                if isBest {
                    Text(L10n.t("calendarView.f3703633"))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.yellow.opacity(0.25)))
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let score = summary.score, summary.activeSeconds > 0 {
                    Text(L10n.t("calendarView.c781cf0f", score.grade, score.total))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    detail(L10n.t("calendarView.f27f893c"), Formatters.compactDuration(summary.activeSeconds))
                    detail(L10n.t("calendarView.cc4b5b89"), Formatters.compactDuration(summary.screenOnSeconds))
                    detail(L10n.t("calendarView.59ca8aa6"), Formatters.groupedNumber(summary.totalKeyPresses))
                }
                GridRow {
                    detail(L10n.t("calendarView.50922e57"), summary.maxWPM > 0 ? Formatters.wpm(summary.maxWPM) : "-")
                    detail(L10n.t("calendarView.068c9e05"), summary.longestFocusSeconds > 0 ? Formatters.compactDuration(summary.longestFocusSeconds) : "-")
                    detail(L10n.t("calendarView.6e3b1fc9"), Formatters.groupedNumber(summary.totalClicks))
                }
            }
            if !summary.activityTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(summary.activityTags.prefix(3), id: \.self) { tag in
                        Text("\(tag.emoji) \(tag.label)")
                            .font(.system(size: 9))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }
            if !summary.summarySentence.isEmpty {
                Text(summary.summarySentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
        }
    }
}
