import XCTest
import PawprintCore
@testable import Pawprint

/// The day's score, and the surplus a day earns past every reference.
///
/// The binding constraint is that the 0–100 band must not move. Grades, percentile samples and
/// every score already shown to anyone are defined on it, so the surplus is additional information
/// rather than a rescaling.
final class ScoreOverflowTests: XCTestCase {

    private func day(activeHours: Double, focusHours: Double, keys: Int, wpm: Double) -> DailySummary {
        var summary = DailySummary(day: "2026-03-09")
        summary.activeSeconds = Int(activeHours * 3600)
        summary.totalFocusSeconds = Int(focusHours * 3600)
        summary.totalKeyPresses = keys
        summary.maxWPM = wpm
        return summary
    }

    /// The reference day: everything exactly at its limit, nothing beyond it.
    private var referenceDay: DailySummary { day(activeHours: 6, focusHours: 2, keys: 8_000, wpm: 80) }

    // MARK: - The band is unchanged

    func testTheBaseStillTopsOutAtOneHundred() {
        XCTAssertEqual(PawprintScore.build(from: referenceDay).total, 100)
        XCTAssertEqual(PawprintScore.build(from: day(activeHours: 24, focusHours: 20,
                                                     keys: 500_000, wpm: 400)).total, 100)
    }

    func testAnEmptyDayScoresZeroWithNoSurplus() {
        let score = PawprintScore.build(from: DailySummary(day: "2026-03-09"))
        XCTAssertEqual(score.total, 0)
        XCTAssertEqual(score.overflow, 0)
        XCTAssertEqual(score.totalIncludingOverflow, 0)
    }

    /// Grades are defined on the base, so a day that overflows is still graded on 100.
    func testGradeReadsTheBaseNotTheSurplus() {
        let huge = PawprintScore.build(from: day(activeHours: 14, focusHours: 6,
                                                 keys: 60_000, wpm: 160))
        XCTAssertEqual(huge.total, 100)
        XCTAssertGreaterThan(huge.overflow, 0)
        XCTAssertEqual(huge.grade, "S")
    }

    // MARK: - The surplus

    /// Reaching the reference is not exceeding it.
    func testExactlyAtTheReferenceEarnsNothingExtra() {
        XCTAssertEqual(PawprintScore.build(from: referenceDay).overflow, 0)
    }

    /// Being a little over must stay at 100. Anything else turns an ordinary good day into
    /// inflation, and the surplus stops meaning "exceptional".
    func testASmallExcessRoundsAwayToNothing() {
        let slightlyOver = day(activeHours: 7.2, focusHours: 2.4, keys: 9_600, wpm: 96)
        let score = PawprintScore.build(from: slightlyOver)
        XCTAssertEqual(score.total, 100)
        XCTAssertEqual(score.overflow, 0, "20% past every reference should not read as exceptional")
    }

    func testALongHardDayEarnsAVisibleSurplus() {
        let score = PawprintScore.build(from: day(activeHours: 9, focusHours: 3.5,
                                                  keys: 20_000, wpm: 105))
        XCTAssertEqual(score.total, 100)
        XCTAssertGreaterThan(score.overflow, 5)
        XCTAssertLessThan(score.overflow, 25)
    }

    /// Bounded, so one runaway afternoon of key repeat cannot produce a number nobody can read.
    func testTheSurplusIsCappedAtFifty() {
        let absurd = day(activeHours: 24, focusHours: 24, keys: 10_000_000, wpm: 5_000)
        XCTAssertLessThanOrEqual(PawprintScore.build(from: absurd).overflow, 50)
        XCTAssertLessThanOrEqual(PawprintScore.build(from: absurd).totalIncludingOverflow, 150)
    }

    /// Monotonic: a bigger day can never score less.
    func testTheSurplusNeverDecreasesAsTheDayGrows() {
        var previous = -1
        for multiple in stride(from: 1.0, through: 4.0, by: 0.25) {
            let score = PawprintScore.build(from: day(activeHours: 6 * multiple,
                                                      focusHours: 2 * multiple,
                                                      keys: Int(8_000 * multiple),
                                                      wpm: 80 * multiple))
            XCTAssertGreaterThanOrEqual(score.overflow, previous, "at \(multiple)x the reference")
            previous = score.overflow
        }
    }

    /// One axis alone cannot carry the surplus past its own share.
    func testEachAxisContributesAtMostHalfItsBase() {
        let typingOnly = day(activeHours: 0, focusHours: 0, keys: 1_000_000, wpm: 0)
        let score = PawprintScore.build(from: typingOnly)
        XCTAssertLessThanOrEqual(score.overflow, 10, "the typing axis is worth 20, so at most 10")
    }

    func testComponentsCarryTheirOwnSurplus() {
        let score = PawprintScore.build(from: day(activeHours: 18, focusHours: 2,
                                                  keys: 8_000, wpm: 80))
        XCTAssertEqual(score.overflow, score.components.reduce(0) { $0 + $1.overflow })
        // Only the axis that was exceeded.
        XCTAssertGreaterThan(score.components[0].overflow, 0)
        XCTAssertEqual(score.components[1].overflow, 0)
        XCTAssertEqual(score.components[2].overflow, 0)
        XCTAssertEqual(score.components[3].overflow, 0)
    }
}
