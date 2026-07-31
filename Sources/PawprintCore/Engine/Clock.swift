import Foundation

/// Where "now" comes from.
///
/// Almost everything Pawprint records is a judgement about time: whether two keystrokes belong to
/// the same typing streak, whether a session has gone idle, which day an event is filed under,
/// whether the day has rolled over. All of it currently reads `Date()` at the point of use, which
/// makes those judgements untestable — a test can supply the input but not the clock, so it either
/// sleeps or asserts nothing.
///
/// One protocol, so a test can hand over a clock it controls.
package protocol Clock: Sendable {
    var now: Date { get }
    /// The calendar day arithmetic is done in. Injected for the same reason as the clock: a test
    /// asserting a day boundary must be able to choose the timezone it happens in.
    var calendar: Calendar { get }
}

extension Clock {
    package var calendar: Calendar { .current }
}

/// The real one.
package struct SystemClock: Clock {
    package init() {}
    package var now: Date { Date() }
    package var calendar: Calendar { .current }
}

/// A clock a test drives by hand.
///
/// `advance` rather than a settable `now`, because the thing worth writing in a test is the shape
/// of the elapsed time — "forty seconds later, then two hours later" — and not a series of
/// absolute instants that have to be recomputed whenever the fixture moves.
package final class TestClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    package let calendar: Calendar

    package init(_ start: Date, calendar: Calendar = .current) {
        current = start
        self.calendar = calendar
    }

    /// Convenience for the common case: a fixed instant in a fixed zone.
    package convenience init(day: String, hour: Int = 9, minute: Int = 0,
                             timeZone: String = "UTC") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let start = formatter.date(from: String(format: "%@ %02d:%02d:00", day, hour, minute))
            ?? Date(timeIntervalSince1970: 0)
        self.init(start, calendar: calendar)
    }

    package var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    @discardableResult
    package func advance(by interval: TimeInterval) -> Date {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
        return current
    }

    package func advance(minutes: Double) -> Date { advance(by: minutes * 60) }
    package func advance(hours: Double) -> Date { advance(by: hours * 3600) }
}
