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
        return text.replacingOccurrences(of: "오늘 ", with: "이번 달 ")
    }

    static func monthTitle(for monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return monthKey }
        return "\(year)년 \(month)월"
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

        add("", monthTitle(for: monthKey), .opener, "\(days.count)일의 기록을 돌아볼게요")

        add("이번 달 함께한 시간", "총 \(Formatters.longSpan(totalActive))",
            .bigNumber(value: Formatters.longSpan(totalActive), unit: ""),
            "하루 평균 \(Formatters.compactDuration(totalActive / max(days.count, 1)))")

        if totalKeys > 0 {
            add("두드린 키", "\(Formatters.compactNumber(totalKeys))번",
                .bigNumber(value: Formatters.compactNumber(totalKeys), unit: "키"),
                monthlyPhrase(FunConversions.keyboardFacts(characterKeys: totalKeys, totalKeys: totalKeys).first?.text))
        }

        if let best = bestWPMDay, best.maxWPM > 0 {
            add("가장 빨랐던 순간", Formatters.wpm(best.maxWPM),
                .highlightDay(day: best.day, detail: "이 날 최고 속도를 냈어요"))
        }

        if let busiest = busiestDay {
            add("가장 뜨거웠던 날", Formatters.dayLabel(busiest.day),
                .highlightDay(day: busiest.day,
                              detail: "\(Formatters.compactDuration(busiest.activeSeconds)) 사용 · \(Formatters.compactNumber(busiest.totalKeyPresses))키"))
        }

        if totalFocus > 0, let focusDay {
            add("집중한 시간", Formatters.longSpan(totalFocus),
                .bigNumber(value: Formatters.longSpan(totalFocus), unit: ""),
                "최장 집중은 \(Formatters.dayLabel(focusDay.day))의 \(Formatters.compactDuration(focusDay.longestFocusSeconds))")
        }

        if totalCursor >= 100 {
            add("커서가 달린 거리", Formatters.compactDistance(meters: totalCursor),
                .bigNumber(value: Formatters.compactDistance(meters: totalCursor), unit: ""),
                monthlyPhrase(FunConversions.cursorFacts(meters: totalCursor).dropFirst().first?.text))
        }

        // Month-over-month, the comparison people actually care about.
        let previousActive = previousMonth.reduce(0) { $0 + $1.activeSeconds }
        if previousActive > 0 {
            let change = (Double(totalActive) - Double(previousActive)) / Double(previousActive) * 100
            let direction = change >= 0 ? "더" : "덜"
            add("지난달과 비교하면",
                String(format: "%.0f%% %@ 썼어요", abs(change), direction),
                .comparison(lead: Formatters.longSpan(totalActive), trail: Formatters.longSpan(previousActive)))
        }

        // Which apps owned the month.
        var appSeconds: [String: TimeInterval] = [:]
        for day in days {
            for app in day.appUsage { appSeconds[app.appName, default: 0] += app.totalSeconds }
        }
        let topApps = appSeconds.sorted { $0.value > $1.value }.prefix(3)
        if !topApps.isEmpty {
            add("가장 오래 머문 곳", "이번 달의 앱",
                .list(items: topApps.map { ($0.key, Formatters.longSpan(Int($0.value))) }))
        }

        // Tag frequency across the month — the month's personality.
        var tagCounts: [ActivityTag: Int] = [:]
        for day in days { for tag in day.activityTags { tagCounts[tag, default: 0] += 1 } }
        if let signature = tagCounts.max(by: { $0.value < $1.value }) {
            add("이번 달의 당신은", "\(signature.key.emoji) \(signature.key.label)",
                .highlightDay(day: monthKey, detail: "\(signature.value)일 동안 이 모습이었어요"))
        }

        let summaryItems: [(String, String)] = [
            ("기록한 날", "\(days.count)일"),
            ("총 사용시간", Formatters.longSpan(totalActive)),
            ("총 키 입력", Formatters.compactNumber(totalKeys)),
            ("총 클릭", Formatters.compactNumber(totalClicks)),
            ("총 집중시간", Formatters.longSpan(totalFocus)),
            ("커서 이동", Formatters.compactDistance(meters: totalCursor)),
            ("스크롤", Formatters.compactNumber(Int(totalScroll)) + "화면"),
            ("최고 속도", bestWPMDay.map { Formatters.wpm($0.maxWPM) } ?? "-"),
        ]

        add("", "\(monthTitle(for: monthKey))의 발자국", .closer, "카드로 저장하거나 공유할 수 있어요")

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
