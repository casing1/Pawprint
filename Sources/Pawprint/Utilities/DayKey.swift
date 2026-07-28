import Foundation

/// Converts wall-clock timestamps into the "day" bucket keys Pawprint stores data under,
/// honoring the user-configurable day-start hour (e.g. a night owl might want their day to
/// start at 4am instead of midnight).
enum DayKey {
    static func string(for date: Date, dayStartHour: Int, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.timeZone = TimeZone.current
        let shifted = cal.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: shifted)
    }

    static func today(dayStartHour: Int) -> String {
        string(for: Date(), dayStartHour: dayStartHour)
    }

    /// Minute-of-day (0...1439) relative to the shifted day boundary, so the per-minute
    /// arrays in `DailyRawCounters` line up with the same day the event was filed under.
    static func minuteOfDay(for date: Date, dayStartHour: Int, calendar: Calendar = .current) -> Int {
        var cal = calendar
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let raw = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return (raw - dayStartHour * 60 + 1440) % 1440
    }

    /// The instant the day containing `date` starts, honouring `dayStartHour`.
    ///
    /// Needed to split anything that straddles a boundary. Without it a session running across
    /// the boundary had to be filed whole under one day or the other, and whichever was chosen
    /// was wrong by however much of it fell on the other side.
    static func dayStart(containing date: Date, dayStartHour: Int,
                         calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.timeZone = TimeZone.current
        let shifted = cal.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let midnight = cal.startOfDay(for: shifted)
        return cal.date(byAdding: .hour, value: dayStartHour, to: midnight) ?? midnight
    }

    /// The next boundary strictly after `date`.
    static func nextDayStart(after date: Date, dayStartHour: Int,
                             calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.timeZone = TimeZone.current
        let start = dayStart(containing: date, dayStartHour: dayStartHour, calendar: cal)
        return cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    static func date(fromDayString day: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: day)
    }

    static func addingDays(_ n: Int, to day: String) -> String {
        guard let date = date(fromDayString: day) else { return day }
        let newDate = Calendar.current.date(byAdding: .day, value: n, to: date) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: newDate)
    }
}
