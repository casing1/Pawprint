import Foundation

/// Aggregate of one week, plus the week-over-week deltas that make the numbers interesting.
package struct WeeklyRollup {
    package var totalActiveSeconds: Int = 0
    package var totalKeyPresses: Int = 0
    package var totalClicks: Int = 0
    package var totalFocusSeconds: Int = 0
    package var cursorDistanceMeters: Double = 0
    package var maxWPM: Double = 0
    package var recordedDays: Int = 0

    /// Percent change in active time vs. the previous week; nil when there's no prior week to
    /// compare against (so the UI can stay quiet instead of showing a meaningless +0%).
    package var activeTimeDeltaPercent: Double?
    package var busiestWeekday: Int?
    package var mostFocusedWeekday: Int?
    package var dominantTag: ActivityTag?

    static package func build(thisWeek: [DailySummary], lastWeek: [DailySummary]) -> WeeklyRollup {
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

    static package func weekdayName(_ weekday: Int) -> String {
        let names = ["", L10n.t("weeklyRollup.06cf3e90"), L10n.t("weeklyRollup.75448692"), L10n.t("weeklyRollup.adb4a282"), L10n.t("weeklyRollup.c04eb2ef"), L10n.t("weeklyRollup.5664a634"), L10n.t("weeklyRollup.cf5632c7"), L10n.t("weeklyRollup.b9e40662")]
        guard weekday >= 1 && weekday < names.count else { return "" }
        return L10n.t("weeklyRollup.80e0471d", names[weekday])
    }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(totalActiveSeconds: Int = 0,
                 totalKeyPresses: Int = 0,
                 totalClicks: Int = 0,
                 totalFocusSeconds: Int = 0,
                 cursorDistanceMeters: Double = 0,
                 maxWPM: Double = 0,
                 recordedDays: Int = 0,
                 activeTimeDeltaPercent: Double? = nil,
                 busiestWeekday: Int? = nil,
                 mostFocusedWeekday: Int? = nil,
                 dominantTag: ActivityTag? = nil) {
        self.totalActiveSeconds = totalActiveSeconds
        self.totalKeyPresses = totalKeyPresses
        self.totalClicks = totalClicks
        self.totalFocusSeconds = totalFocusSeconds
        self.cursorDistanceMeters = cursorDistanceMeters
        self.maxWPM = maxWPM
        self.recordedDays = recordedDays
        self.activeTimeDeltaPercent = activeTimeDeltaPercent
        self.busiestWeekday = busiestWeekday
        self.mostFocusedWeekday = mostFocusedWeekday
        self.dominantTag = dominantTag
    }

}
