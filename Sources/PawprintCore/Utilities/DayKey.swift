import Foundation

/// Converts wall-clock timestamps into the "day" bucket keys Pawprint stores data under,
/// honoring the user-configurable day-start hour (e.g. a night owl might want their day to
/// start at 4am instead of midnight).
///
/// The `calendar` parameter is honoured in full, timezone included. It used to overwrite the
/// timezone with the system's, which made the injection a half-measure: the calendar system was
/// taken and the timezone quietly discarded. Nothing in the app passes a calendar — every caller
/// takes the `.current` default, which carries the system timezone anyway, so behaviour there is
/// unchanged. What it did break was the ability to test a day boundary at all: a test had to run
/// in the machine's own timezone, which is why the suite passed in Seoul and failed on a UTC
/// build runner.
package enum DayKey {
    static package func string(for date: Date, dayStartHour: Int, calendar: Calendar = .current) -> String {
        let cal = calendar
        let shifted = cal.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: shifted)
    }

    static package func today(dayStartHour: Int) -> String {
        string(for: Date(), dayStartHour: dayStartHour)
    }

    /// Minute-of-day (0...1439) relative to the shifted day boundary, so the per-minute
    /// arrays in `DailyRawCounters` line up with the same day the event was filed under.
    static package func minuteOfDay(for date: Date, dayStartHour: Int, calendar: Calendar = .current) -> Int {
        let cal = calendar
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let raw = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return (raw - dayStartHour * 60 + 1440) % 1440
    }

    /// The instant the day containing `date` starts, honouring `dayStartHour`.
    ///
    /// Needed to split anything that straddles a boundary. Without it a session running across
    /// the boundary had to be filed whole under one day or the other, and whichever was chosen
    /// was wrong by however much of it fell on the other side.
    static package func dayStart(containing date: Date, dayStartHour: Int,
                         calendar: Calendar = .current) -> Date {
        let cal = calendar
        let shifted = cal.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let midnight = cal.startOfDay(for: shifted)
        return cal.date(byAdding: .hour, value: dayStartHour, to: midnight) ?? midnight
    }

    /// The next boundary strictly after `date`.
    static package func nextDayStart(after date: Date, dayStartHour: Int,
                             calendar: Calendar = .current) -> Date {
        let cal = calendar
        let start = dayStart(containing: date, dayStartHour: dayStartHour, calendar: cal)
        return cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    static package func date(fromDayString day: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: day)
    }

    /// The wall-clock instant a minute-of-day index falls on.
    ///
    /// Counters are indexed from the user's day start, so minute 0 is 05:00 for someone whose day
    /// begins at five. Anything printing a time has to shift back.
    static package func date(forMinute minute: Int, day: String, dayStartHour: Int) -> Date? {
        guard let dayDate = date(fromDayString: day) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let shiftedMinutes = minute + dayStartHour * 60
        return calendar.date(byAdding: .minute, value: shiftedMinutes, to: dayDate)
    }

    static package func addingDays(_ n: Int, to day: String) -> String {
        guard let date = date(fromDayString: day) else { return day }
        let newDate = Calendar.current.date(byAdding: .day, value: n, to: date) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: newDate)
    }
}
