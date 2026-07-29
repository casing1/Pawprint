import XCTest
import PawprintCore
@testable import Pawprint

/// The streak rule, which decides the cat's collar.
///
/// Ported from the `PAWPRINT_STREAK` probe so the same assertions run under `swift test` on every
/// build rather than only when someone remembers to launch the app with an environment variable.
/// The probe stays: it exercises the rule inside a running app, which is a different question.
final class StreakRuleTests: XCTestCase {

    private let start = "2026-01-01"

    private func day(_ key: String, active: Bool = true) -> DailySummary {
        var summary = DailySummary(day: key)
        if active {
            summary.activeSeconds = 3_600
            summary.totalKeyPresses = 2_000
        }
        return summary
    }

    private func run(_ count: Int, from origin: String) -> [DailySummary] {
        (0..<count).map { day(DayKey.addingDays($0, to: origin)) }
    }

    func testFirstDayOfARunCountsOne() {
        XCTAssertEqual(StreakRule.streaks(for: run(40, from: start))[start], 1)
    }

    /// The count used to be taken from a seven-day cache, which capped it at 8 and put the collars
    /// needing 14 and 30 consecutive days permanently out of reach.
    func testALongRunIsNotCappedAtEight() {
        let streaks = StreakRule.streaks(for: run(40, from: start))
        XCTAssertEqual(streaks[DayKey.addingDays(7, to: start)], 8)
        XCTAssertEqual(streaks[DayKey.addingDays(39, to: start)], 40)
    }

    func testAGapResetsTheCountAndDaysBeforeItKeepTheirs() {
        let broken = run(5, from: start)
            + [day(DayKey.addingDays(5, to: start), active: false)]
            + (6..<9).map { day(DayKey.addingDays($0, to: start)) }
        let streaks = StreakRule.streaks(for: broken)

        XCTAssertEqual(streaks[DayKey.addingDays(4, to: start)], 5)
        XCTAssertNil(streaks[DayKey.addingDays(5, to: start)], "an inactive day has no streak")
        XCTAssertEqual(streaks[DayKey.addingDays(6, to: start)], 1)
    }

    /// The app answers this question two ways — a single walk backwards for today, a forward pass
    /// for the whole gallery. They must agree, or the Today tab and the gallery will disagree
    /// about the same day, which is the bug this rule was extracted to fix.
    func testTheWalkAndTheBatchPassAgree() {
        let days = run(40, from: start)
        let active = Set(days.map(\.day))
        let last = DayKey.addingDays(39, to: start)

        let walked = StreakRule.streak(endingOn: last) { active.contains($0) }
        XCTAssertEqual(walked, StreakRule.streaks(for: days)[last])
    }

    func testAnInactiveDayIsNotActive() {
        XCTAssertFalse(StreakRule.isActive(day("2026-01-01", active: false)))
        XCTAssertTrue(StreakRule.isActive(day("2026-01-01")))
    }

    /// A day the Mac was merely switched on, with nothing recorded, must not extend a streak.
    func testAnEmptyDayDoesNotExtendAStreak() {
        var barelyOn = DailySummary(day: DayKey.addingDays(1, to: start))
        barelyOn.activeSeconds = 0
        barelyOn.totalKeyPresses = 0

        let streaks = StreakRule.streaks(for: [day(start), barelyOn,
                                               day(DayKey.addingDays(2, to: start))])
        XCTAssertEqual(streaks[start], 1)
        XCTAssertEqual(streaks[DayKey.addingDays(2, to: start)], 1)
    }

    // MARK: - What the user sees

    /// Each tier of the collar, so a change to the thresholds is a deliberate one.
    @MainActor
    func testEachStreakLengthEarnsItsCollar() {
        let expected: [(Int, PawpetTraits.Collar)] = [
            (0, .none), (1, .cloth), (2, .cloth), (3, .blue), (6, .blue),
            (7, .green), (13, .green), (14, .gold), (29, .gold), (30, .rainbow), (400, .rainbow),
        ]
        for (days, collar) in expected {
            let traits = PawpetTraits.forDay(day("2026-03-14"), streakDays: days)
            XCTAssertEqual(traits.collar, collar, "a \(days)-day streak")
        }
    }

    /// The regression itself: a day in the middle of history is not today, and used to be handed a
    /// streak of zero purely for that reason — which took the collar off every cat the day after
    /// it was earned.
    @MainActor
    func testAPastDayKeepsTheCollarItEarned() {
        let days = run(40, from: start)
        let past = days[20]
        let streak = StreakRule.streaks(for: days)[past.day] ?? 0

        XCTAssertEqual(streak, 21)
        XCTAssertEqual(PawpetTraits.forDay(past, streakDays: streak).collar, .gold)
    }
}
