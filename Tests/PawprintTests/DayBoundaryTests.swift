import XCTest
import PawprintCore
@testable import Pawprint

/// Day boundaries, pinned before anything moves.
///
/// Every stored figure is filed under a day string, so a change in how that string is derived
/// silently re-files history. `DayKey` already takes an injected `Calendar`, so none of this needs
/// the wall clock: each test builds the exact instant it means.
final class DayBoundaryTests: XCTestCase {

    /// A fixed calendar. Seoul has no daylight saving, which makes it the right default for the
    /// cases that are *not* about DST.
    private func calendar(_ identifier: String = "Asia/Seoul") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(_ text: String, _ calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }

    // MARK: - dayStartHour = 0

    func testMidnightStartsTheNextDay() {
        let cal = calendar()
        XCTAssertEqual(DayKey.string(for: date("2026-03-09 23:59:59", cal), dayStartHour: 0, calendar: cal),
                       "2026-03-09")
        XCTAssertEqual(DayKey.string(for: date("2026-03-10 00:00:00", cal), dayStartHour: 0, calendar: cal),
                       "2026-03-10")
    }

    // MARK: - Custom dayStartHour

    /// With a 4am start, 2am belongs to the day before — the point of the setting is that a night
    /// owl's session is one day, not two.
    func testHoursBeforeTheCustomStartBelongToThePreviousDay() {
        let cal = calendar()
        let start = 4
        XCTAssertEqual(DayKey.string(for: date("2026-03-10 02:00:00", cal), dayStartHour: start, calendar: cal),
                       "2026-03-09")
        XCTAssertEqual(DayKey.string(for: date("2026-03-10 03:59:59", cal), dayStartHour: start, calendar: cal),
                       "2026-03-09")
        XCTAssertEqual(DayKey.string(for: date("2026-03-10 04:00:00", cal), dayStartHour: start, calendar: cal),
                       "2026-03-10")
    }

    /// Minute-of-day is measured from the custom start, not from midnight, so the per-minute
    /// buckets line up with the day they are filed under.
    func testMinuteOfDayIsRelativeToTheCustomStart() {
        let cal = calendar()
        XCTAssertEqual(DayKey.minuteOfDay(for: date("2026-03-10 04:00:00", cal), dayStartHour: 4, calendar: cal), 0)
        XCTAssertEqual(DayKey.minuteOfDay(for: date("2026-03-10 05:30:00", cal), dayStartHour: 4, calendar: cal), 90)
        XCTAssertEqual(DayKey.minuteOfDay(for: date("2026-03-10 00:00:00", cal), dayStartHour: 0, calendar: cal), 0)
        XCTAssertEqual(DayKey.minuteOfDay(for: date("2026-03-10 23:59:00", cal), dayStartHour: 0, calendar: cal), 1439)
    }

    func testDayStartAndNextDayStartBracketTheInstant() {
        let cal = calendar()
        let instant = date("2026-03-10 15:22:00", cal)
        let start = DayKey.dayStart(containing: instant, dayStartHour: 4, calendar: cal)
        let next = DayKey.nextDayStart(after: instant, dayStartHour: 4, calendar: cal)

        XCTAssertLessThanOrEqual(start, instant)
        XCTAssertGreaterThan(next, instant)
        XCTAssertEqual(next.timeIntervalSince(start), 24 * 3600, accuracy: 1)
    }

    // MARK: - Arithmetic

    func testAddingDaysCrossesMonthAndYear() {
        XCTAssertEqual(DayKey.addingDays(1, to: "2026-03-09"), "2026-03-10")
        XCTAssertEqual(DayKey.addingDays(-1, to: "2026-03-01"), "2026-02-28")
        XCTAssertEqual(DayKey.addingDays(1, to: "2026-12-31"), "2027-01-01")
        XCTAssertEqual(DayKey.addingDays(-1, to: "2027-01-01"), "2026-12-31")
    }

    /// 2028 is a leap year; 2026 is not.
    func testAddingDaysHandlesLeapDay() {
        XCTAssertEqual(DayKey.addingDays(1, to: "2028-02-28"), "2028-02-29")
        XCTAssertEqual(DayKey.addingDays(1, to: "2028-02-29"), "2028-03-01")
        XCTAssertEqual(DayKey.addingDays(1, to: "2026-02-28"), "2026-03-01")
    }

    func testDayStringRoundTripsThroughDate() {
        for day in ["2026-01-01", "2026-02-28", "2026-07-30", "2026-12-31", "2028-02-29"] {
            guard let parsed = DayKey.date(fromDayString: day) else {
                return XCTFail("\(day) did not parse")
            }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            XCTAssertEqual(DayKey.string(for: parsed, dayStartHour: 0, calendar: cal), day)
        }
    }

    func testMalformedDayStringsDoNotCrash() {
        XCTAssertNil(DayKey.date(fromDayString: ""))
        XCTAssertNil(DayKey.date(fromDayString: "not-a-day"))
        XCTAssertNil(DayKey.date(fromDayString: "2026-13-45"))
    }

    // MARK: - Daylight saving

    /// New York springs forward at 2am on 8 March 2026: 02:00–02:59 does not exist. The day key
    /// must still be the calendar day, and the day must still be 24 hours wide as far as the
    /// bucket arithmetic is concerned.
    func testSpringForwardKeepsTheDayIntact() {
        let cal = calendar("America/New_York")
        XCTAssertEqual(DayKey.string(for: date("2026-03-08 01:30:00", cal), dayStartHour: 0, calendar: cal),
                       "2026-03-08")
        XCTAssertEqual(DayKey.string(for: date("2026-03-08 03:30:00", cal), dayStartHour: 0, calendar: cal),
                       "2026-03-08")

        let minute = DayKey.minuteOfDay(for: date("2026-03-08 03:30:00", cal), dayStartHour: 0, calendar: cal)
        XCTAssertGreaterThanOrEqual(minute, 0)
        XCTAssertLessThan(minute, 1440, "a shortened day must not produce an out-of-range bucket")
    }

    /// Falling back repeats 01:00–01:59. Both repetitions belong to the same day and must land in
    /// a valid bucket.
    func testFallBackKeepsBucketsInRange() {
        let cal = calendar("America/New_York")
        let day = date("2026-11-01 01:30:00", cal)
        XCTAssertEqual(DayKey.string(for: day, dayStartHour: 0, calendar: cal), "2026-11-01")

        let minute = DayKey.minuteOfDay(for: day, dayStartHour: 0, calendar: cal)
        XCTAssertGreaterThanOrEqual(minute, 0)
        XCTAssertLessThan(minute, 1440)
    }
}
