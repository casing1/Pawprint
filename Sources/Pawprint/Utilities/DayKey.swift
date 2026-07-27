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
