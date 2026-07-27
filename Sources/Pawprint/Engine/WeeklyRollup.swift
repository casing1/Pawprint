import Foundation

/// Aggregate of one week, plus the week-over-week deltas that make the numbers interesting.
struct WeeklyRollup {
    var totalActiveSeconds: Int = 0
    var totalKeyPresses: Int = 0
    var totalClicks: Int = 0
    var totalFocusSeconds: Int = 0
    var cursorDistanceMeters: Double = 0
    var maxWPM: Double = 0
    var recordedDays: Int = 0

    /// Percent change in active time vs. the previous week; nil when there's no prior week to
    /// compare against (so the UI can stay quiet instead of showing a meaningless +0%).
    var activeTimeDeltaPercent: Double?
    var busiestWeekday: Int?
    var mostFocusedWeekday: Int?
    var dominantTag: ActivityTag?

    static func build(thisWeek: [DailySummary], lastWeek: [DailySummary]) -> WeeklyRollup {
        var r = WeeklyRollup()
        guard !thisWeek.isEmpty else { return r }

        r.totalActiveSeconds = thisWeek.reduce(0) { $0 + $1.activeSeconds }
        r.totalKeyPresses = thisWeek.reduce(0) { $0 + $1.totalKeyPresses }
        r.totalClicks = thisWeek.reduce(0) { $0 + $1.totalClicks }
        r.totalFocusSeconds = thisWeek.reduce(0) { $0 + $1.totalFocusSeconds }
        r.cursorDistanceMeters = thisWeek.reduce(0) { $0 + $1.cursorDistanceMeters }
        r.maxWPM = thisWeek.map(\.maxWPM).max() ?? 0
        r.recordedDays = thisWeek.filter { $0.activeSeconds > 0 }.count

        let lastWeekActive = lastWeek.reduce(0) { $0 + $1.activeSeconds }
        if lastWeekActive > 0 {
            r.activeTimeDeltaPercent = (Double(r.totalActiveSeconds) - Double(lastWeekActive)) / Double(lastWeekActive) * 100
        }

        let calendar = Calendar.current
        if let busiest = thisWeek.max(by: { $0.activeSeconds < $1.activeSeconds }),
           busiest.activeSeconds > 0,
           let date = DayKey.date(fromDayString: busiest.day) {
            r.busiestWeekday = calendar.component(.weekday, from: date)
        }
        if let focused = thisWeek.max(by: { $0.totalFocusSeconds < $1.totalFocusSeconds }),
           focused.totalFocusSeconds > 0,
           let date = DayKey.date(fromDayString: focused.day) {
            r.mostFocusedWeekday = calendar.component(.weekday, from: date)
        }

        var tagCounts: [ActivityTag: Int] = [:]
        for summary in thisWeek {
            for tag in summary.activityTags {
                tagCounts[tag, default: 0] += 1
            }
        }
        r.dominantTag = tagCounts.max { $0.value < $1.value }?.key

        return r
    }

    static func weekdayName(_ weekday: Int) -> String {
        let names = ["", "일", "월", "화", "수", "목", "금", "토"]
        guard weekday >= 1 && weekday < names.count else { return "" }
        return "\(names[weekday])요일"
    }
}
