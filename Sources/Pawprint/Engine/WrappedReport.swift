import Foundation

/// A month condensed into a handful of dramatic reveals.
///
/// Built entirely from stored daily summaries — no new tracking. The slide list is assembled
/// dynamically so a sparse month simply produces fewer slides rather than a wall of zeroes.
struct WrappedReport {
    struct Slide: Identifiable {
        enum Kind {
            case opener
            case bigNumber(value: String, unit: String)
            case comparison(lead: String, trail: String)
            case highlightDay(day: String, detail: String)
            case list(items: [(String, String)])
            case closer
        }

        var id: Int
        var eyebrow: String
        var headline: String
        var kind: Kind
        var footnote: String?
    }

    var monthKey: String          // "2026-07"
    var title: String             // "2026년 7월"
    var dayCount: Int
    var slides: [Slide]
    /// Headline figures reused by the shareable summary card at the end.
    var summaryItems: [(String, String)]

    /// The conversion engine writes in a daily voice ("오늘 …"). Reused here it would claim a
    /// month's totals happened today, so the subject is rewritten for the retrospective.
    private static func monthlyPhrase(_ text: String?) -> String? {
        guard let text else { return nil }
        return text.replacingOccurrences(of: L10n.t("wrappedReport.8bd1dd77"), with: L10n.t("wrappedReport.b062d55e"))
    }

    static func monthTitle(for monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return monthKey }
        return L10n.t("wrappedReport.7a6f23a4", year, month)
    }

    /// Builds a report for the given month key ("yyyy-MM"). Returns nil when the month has no
    /// meaningful activity — an empty retrospective is worse than none.
    static func build(monthKey: String, summaries: [DailySummary], previousMonth: [DailySummary]) -> WrappedReport? {
        let days = summaries.filter { $0.day.hasPrefix(monthKey) && ($0.activeSeconds > 0 || $0.totalKeyPresses > 0) }
        guard days.count >= 2 else { return nil }

        let totalActive = days.reduce(0) { $0 + $1.activeSeconds }
        let totalKeys = days.reduce(0) { $0 + $1.totalKeyPresses }
        let totalClicks = days.reduce(0) { $0 + $1.totalClicks }
        let totalFocus = days.reduce(0) { $0 + $1.totalFocusSeconds }
        let totalCursor = days.reduce(0.0) { $0 + $1.cursorDistanceMeters }
        let totalScroll = days.reduce(0.0) { $0 + $1.scrollScreens }
        let bestWPMDay = days.max { $0.maxWPM < $1.maxWPM }
        let busiestDay = days.max { $0.activeSeconds < $1.activeSeconds }
        let focusDay = days.max { $0.longestFocusSeconds < $1.longestFocusSeconds }

        var slides: [Slide] = []
        var index = 0
        func add(_ eyebrow: String, _ headline: String, _ kind: Slide.Kind, _ footnote: String? = nil) {
            slides.append(Slide(id: index, eyebrow: eyebrow, headline: headline, kind: kind, footnote: footnote))
            index += 1
        }

        add("", monthTitle(for: monthKey), .opener, L10n.t("wrappedReport.9b09776a", days.count))

        add(L10n.t("wrappedReport.7be87d01"), L10n.t("wrappedReport.84152b81", Formatters.longSpan(totalActive)),
            .bigNumber(value: Formatters.longSpan(totalActive), unit: ""),
            L10n.t("wrappedReport.fa730e90", Formatters.compactDuration(totalActive / max(days.count, 1))))

        if totalKeys > 0 {
            add(L10n.t("wrappedReport.d42c2d41"), L10n.t("wrappedReport.13adce96", Formatters.compactNumber(totalKeys)),
                .bigNumber(value: Formatters.compactNumber(totalKeys), unit: L10n.t("wrappedReport.31618a08")),
                monthlyPhrase(FunConversions.keyboardFacts(characterKeys: totalKeys, totalKeys: totalKeys).first?.text))
        }

        if let best = bestWPMDay, best.maxWPM > 0 {
            add(L10n.t("wrappedReport.0b7a9c1a"), Formatters.wpm(best.maxWPM),
                .highlightDay(day: best.day, detail: L10n.t("wrappedReport.23e0f864")))
        }

        if let busiest = busiestDay {
            add(L10n.t("wrappedReport.a3447b8e"), Formatters.dayLabel(busiest.day),
                .highlightDay(day: busiest.day,
                              detail: L10n.t("wrappedReport.868e2dd4", Formatters.compactDuration(busiest.activeSeconds), Formatters.compactNumber(busiest.totalKeyPresses))))
        }

        if totalFocus > 0, let focusDay {
            add(L10n.t("wrappedReport.439c5286"), Formatters.longSpan(totalFocus),
                .bigNumber(value: Formatters.longSpan(totalFocus), unit: ""),
                L10n.t("wrappedReport.fc216e75", Formatters.dayLabel(focusDay.day), Formatters.compactDuration(focusDay.longestFocusSeconds)))
        }

        if totalCursor >= 100 {
            add(L10n.t("wrappedReport.b11e6a60"), Formatters.compactDistance(meters: totalCursor),
                .bigNumber(value: Formatters.compactDistance(meters: totalCursor), unit: ""),
                monthlyPhrase(FunConversions.cursorFacts(meters: totalCursor).dropFirst().first?.text))
        }

        // Month-over-month, the comparison people actually care about.
        let previousActive = previousMonth.reduce(0) { $0 + $1.activeSeconds }
        if previousActive > 0 {
            let change = (Double(totalActive) - Double(previousActive)) / Double(previousActive) * 100
            let direction = change >= 0 ? L10n.t("wrappedReport.a20f2464") : L10n.t("wrappedReport.9f9037e6")
            add(L10n.t("wrappedReport.19868e83"),
                String(format: L10n.t("wrappedReport.97996a20"), abs(change), direction),
                .comparison(lead: Formatters.longSpan(totalActive), trail: Formatters.longSpan(previousActive)))
        }

        // Which apps owned the month.
        var appSeconds: [String: TimeInterval] = [:]
        for day in days {
            for app in day.appUsage { appSeconds[app.appName, default: 0] += app.totalSeconds }
        }
        let topApps = appSeconds.sorted { $0.value > $1.value }.prefix(3)
        if !topApps.isEmpty {
            add(L10n.t("wrappedReport.046fcfa3"), L10n.t("wrappedReport.f10d2165"),
                .list(items: topApps.map { ($0.key, Formatters.longSpan(Int($0.value))) }))
        }

        // Tag frequency across the month — the month's personality.
        var tagCounts: [ActivityTag: Int] = [:]
        for day in days { for tag in day.activityTags { tagCounts[tag, default: 0] += 1 } }
        if let signature = tagCounts.max(by: { $0.value < $1.value }) {
            add(L10n.t("wrappedReport.c5acd03a"), "\(signature.key.emoji) \(signature.key.label)",
                .highlightDay(day: monthKey, detail: L10n.t("wrappedReport.4afb3c8b", signature.value)))
        }

        let summaryItems: [(String, String)] = [
            (L10n.t("wrappedReport.79df15ef"), L10n.t("wrappedReport.cec3694e", days.count)),
            (L10n.t("wrappedReport.49d8f80b"), Formatters.longSpan(totalActive)),
            (L10n.t("wrappedReport.110bf3ae"), Formatters.compactNumber(totalKeys)),
            (L10n.t("wrappedReport.866e0ee4"), Formatters.compactNumber(totalClicks)),
            (L10n.t("wrappedReport.da8dd921"), Formatters.longSpan(totalFocus)),
            (L10n.t("wrappedReport.7c2c694b"), Formatters.compactDistance(meters: totalCursor)),
            (L10n.t("wrappedReport.daa69457"), Formatters.compactNumber(Int(totalScroll)) + L10n.t("wrappedReport.43c786f1")),
            (L10n.t("wrappedReport.50922e57"), bestWPMDay.map { Formatters.wpm($0.maxWPM) } ?? "-"),
        ]

        add("", L10n.t("wrappedReport.6092d116", monthTitle(for: monthKey)), .closer, L10n.t("wrappedReport.c03b6594"))

        return WrappedReport(
            monthKey: monthKey,
            title: monthTitle(for: monthKey),
            dayCount: days.count,
            slides: slides,
            summaryItems: summaryItems
        )
    }

    /// Month keys that have enough data to be worth reviewing, newest first.
    static func availableMonths(from summaries: [DailySummary]) -> [String] {
        var counts: [String: Int] = [:]
        for summary in summaries where summary.activeSeconds > 0 || summary.totalKeyPresses > 0 {
            counts[String(summary.day.prefix(7)), default: 0] += 1
        }
        return counts.filter { $0.value >= 2 }.keys.sorted(by: >)
    }
}

/// Sheet-presentation wrapper so a month key can drive `.sheet(item:)`.
struct WrappedMonth: Identifiable {
    var id: String

    /// Month key immediately preceding the given one, used for the month-over-month slide.
    static func previousKey(of monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return monthKey }
        return month == 1
            ? String(format: "%04d-12", year - 1)
            : String(format: "%04d-%02d", year, month - 1)
    }
}
