import XCTest
import PawprintCore
@testable import Pawprint

/// That rarity is one figure that accounts for both halves of a day.
///
/// It used to be the item total alone, which meant a settled user earned nearly the same number
/// every day: the same items keep being granted, so the same score keeps coming out. On the
/// 117-day demo history that produced 31 distinct values with eighteen days sharing one of them.
/// What separates those days is not what the cat is wearing but what the day was.
@MainActor
final class RarityScoreTests: XCTestCase {

    /// A day with the effort dials set where the caller asks and nothing else going on.
    private func day(_ key: String, activeHours: Double, keys: Int, wpm: Double) -> DailySummary {
        var summary = DailySummary(day: key)
        summary.activeSeconds = Int(activeHours * 3600)
        summary.totalFocusSeconds = Int(activeHours * 1800)
        summary.totalKeyPresses = keys
        summary.characterKeyPresses = Int(Double(keys) * 0.8)
        summary.maxWPM = wpm
        summary.scrollScreens = activeHours * 40
        summary.cursorDistanceMeters = activeHours * 20
        return summary
    }

    private func traits(_ summary: DailySummary) -> PawpetTraits {
        PawpetTraits.forDay(summary, streakDays: 0)
    }

    // MARK: - The combination

    /// The whole point: for a *fixed* set of items, the day still moves the score.
    ///
    /// Stated against the formula rather than against two fixtures, because items are themselves
    /// earned from the day — a quiet day and a busy one never carry the same frame, so no pair of
    /// real days can isolate the effect. This is the property that pair would have shown.
    func testTheDayMovesTheScoreEvenWhenTheItemsDoNot() {
        let quiet = day("2026-03-01", activeHours: 1, keys: 500, wpm: 30)
        let busy = day("2026-03-01", activeHours: 7, keys: 12_000, wpm: 95)
        let items = 48.0

        let quietScore = 0.70 * items + 0.30 * CatLustre.compute(itemPoints: items, summary: quiet).effort * 100
        let busyScore = 0.70 * items + 0.30 * CatLustre.compute(itemPoints: items, summary: busy).effort * 100
        XCTAssertGreaterThan(busyScore, quietScore + 5,
                             "identical items, and the harder day scored no better")
    }

    /// And in practice, where the items move too, the harder day still comes out ahead.
    func testAHarderDayScoresHigherEndToEnd() {
        let quiet = traits(day("2026-03-01", activeHours: 1, keys: 500, wpm: 30))
        let busy = traits(day("2026-03-01", activeHours: 7, keys: 12_000, wpm: 95))
        XCTAssertGreaterThan(busy.rarityScore, quiet.rarityScore)
    }

    /// Effort raises rarity, but it cannot carry a bare cat to the top: rarity is still a statement
    /// about the cat, which is why items keep the larger share.
    func testItemsKeepTheLargerShare() {
        let bare = traits(day("2026-03-01", activeHours: 9, keys: 40_000, wpm: 130))
        // Effort alone is worth at most 30 points.
        XCTAssertLessThanOrEqual(bare.rarityScore, bare.rarityPoints * 0.70 + 30.001)
        XCTAssertGreaterThanOrEqual(bare.rarityScore, bare.rarityPoints * 0.70 - 0.001)
    }

    /// A day with nothing on it scores nothing, not a floor.
    func testAnEmptyDayScoresZero() {
        let empty = traits(DailySummary(day: "2026-03-01"))
        XCTAssertEqual(empty.rarityScore, empty.rarityPoints * 0.70, accuracy: 0.01)
    }

    // MARK: - Precision

    /// Two decimals, because that is where the separation actually shows.
    func testTheScoreIsReportedToTwoDecimals() {
        let summary = day("2026-05-14", activeHours: 4.3, keys: 6_100, wpm: 71)
        let t = traits(summary)
        XCTAssertEqual(t.rarityDisplay, String(format: "%.2f", t.rarityScore))
        XCTAssertEqual(t.rarityDisplay.split(separator: ".").last?.count, 2)
        // Rounded to the hundredth, not merely printed that way.
        XCTAssertEqual(t.rarityScore, (t.rarityScore * 100).rounded() / 100, accuracy: 1e-9)
    }

    func testTheScoreStaysInsideTheScale() {
        for hours in [0.0, 0.5, 3, 6, 12, 24] {
            for keys in [0, 500, 8_000, 60_000] {
                let t = traits(day("2026-07-04", activeHours: hours, keys: keys, wpm: 140))
                XCTAssertGreaterThanOrEqual(t.rarityScore, 0)
                XCTAssertLessThanOrEqual(t.rarityScore, 100)
            }
        }
    }

    /// The grade is the rounded score, so the badge and the number never disagree.
    func testTheGradeFollowsTheCombinedScore() {
        let t = traits(day("2026-06-05", activeHours: 6, keys: 15_000, wpm: 100))
        XCTAssertEqual(t.rarity, Int(t.rarityScore.rounded()))
    }

    // MARK: - No double counting

    /// Rarity folds in the day through `lustre.effort`, never through `lustre.value` — the value
    /// already carries the item total at 0.40, and blending with it would count the items twice.
    func testRarityUsesTheEffortShareRatherThanTheBlendedLustre() {
        let summary = day("2026-06-05", activeHours: 5, keys: 9_000, wpm: 88)
        let t = traits(summary)

        let expected = 0.70 * t.rarityPoints + 0.30 * (t.lustre.effort * 100)
        XCTAssertEqual(t.rarityScore, min(100, (expected * 100).rounded() / 100), accuracy: 0.011)

        // And the two figures remain different questions: lustre leans on the day, rarity on the
        // cat, so on an item-poor but hard-worked day lustre must sit above rarity.
        XCTAssertGreaterThan(t.lustre.value, t.rarityScore,
                             "lustre stopped being the day-led figure")
    }

    /// `effort` is the day's own contribution and must not move when only the items do.
    func testEffortIsIndependentOfTheItems() {
        let summary = day("2026-06-05", activeHours: 5, keys: 9_000, wpm: 88)
        let a = CatLustre.compute(itemPoints: 10, summary: summary)
        let b = CatLustre.compute(itemPoints: 90, summary: summary)

        XCTAssertEqual(a.effort, b.effort, accuracy: 1e-12, "effort moved with the items")
        XCTAssertGreaterThan(b.value, a.value, "the blended value should still follow the items")
    }

    // MARK: - Monotonicity

    /// More of a good day never scores less. Checked across the whole scale rather than at a point,
    /// because an eased curve is exactly the kind of thing that can fold back on itself.
    func testMoreEffortNeverScoresLess() {
        var previous = -1.0
        for hours in stride(from: 0.0, through: 12.0, by: 0.5) {
            let score = traits(day("2026-06-05", activeHours: hours,
                                   keys: Int(hours * 1_500), wpm: 60 + hours)).rarityScore
            XCTAssertGreaterThanOrEqual(score, previous - 0.001,
                                        "score fell going from a lighter day to a heavier one")
            previous = score
        }
    }
}
