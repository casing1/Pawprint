import XCTest
import PawprintCore
@testable import Pawprint

/// Lustre exists to do one thing rarity cannot: separate two cats that earned the same items.
///
/// So that is what these check — not a hand-copied expected value, but the property the feature was
/// added for. On the 115-day history the app ships screenshots of, rarity produces 26 distinct
/// values with 23 days sharing one of them; lustre produces 108 with a worst case of two.
final class CatLustreTests: XCTestCase {

    private func day(_ key: String = "2026-03-09",
                     activeHours: Double = 5, focusHours: Double = 2,
                     keys: Int = 20_000, wpm: Double = 90,
                     screens: Double = 300, metres: Double = 120) -> DailySummary {
        var summary = DailySummary(day: key)
        summary.activeSeconds = Int(activeHours * 3600)
        summary.totalFocusSeconds = Int(focusHours * 3600)
        summary.totalKeyPresses = keys
        summary.maxWPM = wpm
        summary.scrollScreens = screens
        summary.cursorDistanceMeters = metres
        return summary
    }

    // MARK: - The point of it

    /// Identical items, different days. This is the case rarity reports as a tie.
    func testTwoDaysWithIdenticalItemsStillSeparate() {
        let quiet = CatLustre.compute(itemPoints: 92, summary: day(activeHours: 4, focusHours: 1.2,
                                                                   keys: 9_000, wpm: 72,
                                                                   screens: 180, metres: 70))
        let heavy = CatLustre.compute(itemPoints: 92, summary: day(activeHours: 8, focusHours: 3.4,
                                                                   keys: 34_000, wpm: 118,
                                                                   screens: 520, metres: 210))
        XCTAssertNotEqual(quiet.value, heavy.value)
        XCTAssertGreaterThan(heavy.value, quiet.value)
        XCTAssertGreaterThan(heavy.value - quiet.value, 5,
                             "the separation has to be big enough to see, not just non-zero")
    }

    /// A hundred days that vary the way real days vary — every axis moving a little — must not
    /// collapse into a handful of values.
    func testRealisticDaysProduceDistinctValues() {
        let values = (0..<100).map { i in
            let k = Double(i)
            return CatLustre.compute(itemPoints: 92,
                                     summary: day(activeHours: 5 + k * 0.02,
                                                  focusHours: 2 + k * 0.01,
                                                  keys: 20_000 + i * 120,
                                                  wpm: 90 + k * 0.4,
                                                  screens: 300 + k * 2,
                                                  metres: 120 + k)).display
        }
        XCTAssertEqual(Set(values).count, values.count)
    }

    /// The actual resolution, stated rather than wished for.
    ///
    /// Lustre averages six axes, so a day that differs on *one* of them by one percent moves by
    /// about a sixth of that and can land on the same two decimals — and it should, because that
    /// is the same day. What it must separate is days that differ the way days differ: a little
    /// on everything.
    func testAFivePercentDayIsAlreadyADifferentCard() {
        let base = CatLustre.compute(itemPoints: 92, summary: day())
        let slightlyBigger = CatLustre.compute(
            itemPoints: 92,
            summary: day(activeHours: 5.25, focusHours: 2.1, keys: 21_000,
                         wpm: 94.5, screens: 315, metres: 126))
        XCTAssertNotEqual(base.display, slightlyBigger.display)
        XCTAssertGreaterThan(slightlyBigger.value, base.value)
    }

    // MARK: - Shape

    func testItStaysInRange() {
        for items in stride(from: 0.0, through: 100.0, by: 10) {
            for hours in stride(from: 0.0, through: 20.0, by: 4) {
                let value = CatLustre.compute(itemPoints: items,
                                              summary: day(activeHours: hours,
                                                           focusHours: hours / 3,
                                                           keys: Int(hours * 5_000),
                                                           wpm: hours * 15,
                                                           screens: hours * 90,
                                                           metres: hours * 40)).value
                XCTAssertGreaterThanOrEqual(value, 0)
                XCTAssertLessThanOrEqual(value, 100)
                XCTAssertFalse(value.isNaN)
            }
        }
    }

    func testAnEmptyDayIsMatteAndScoresOnlyItsItems() {
        let nothing = CatLustre.compute(itemPoints: 0, summary: DailySummary(day: "2026-03-09"))
        XCTAssertEqual(nothing.value, 0)
        XCTAssertEqual(nothing.finish, .matte)
    }

    /// More items, same day, cannot lower the result; and the reverse.
    func testItIsMonotonicInBothInputs() {
        var previous = -1.0
        for items in stride(from: 0.0, through: 100.0, by: 5) {
            let value = CatLustre.compute(itemPoints: items, summary: day()).value
            XCTAssertGreaterThan(value, previous)
            previous = value
        }
        previous = -1
        for hours in stride(from: 0.0, through: 12.0, by: 1) {
            let value = CatLustre.compute(itemPoints: 60, summary: day(activeHours: hours)).value
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    // MARK: - Finish

    func testFinishFollowsTheBandsAndIntensityStaysNormalised() {
        for finish in CatLustre.Finish.allCases {
            let lustre = CatLustre(value: finish.threshold + 0.01, finish: finish, intensity: 0)
            XCTAssertEqual(lustre.finish, finish)
        }
        for items in stride(from: 0.0, through: 100.0, by: 3) {
            let lustre = CatLustre.compute(itemPoints: items, summary: day())
            XCTAssertGreaterThanOrEqual(lustre.value, lustre.finish.threshold)
            XCTAssertGreaterThanOrEqual(lustre.intensity, 0)
            XCTAssertLessThanOrEqual(lustre.intensity, 1)
        }
    }

    func testFinishesAreOrdered() {
        XCTAssertLessThan(CatLustre.Finish.matte, .satin)
        XCTAssertLessThan(CatLustre.Finish.satin, .holographic)
        XCTAssertLessThan(CatLustre.Finish.holographic, .prismatic)
        XCTAssertLessThan(CatLustre.Finish.prismatic, .radiant)
    }

    func testDisplayIsTwoDecimalPlaces() {
        XCTAssertEqual(CatLustre(value: 87.804, finish: .prismatic, intensity: 0.4).display, "87.80")
        XCTAssertEqual(CatLustre(value: 93.0, finish: .radiant, intensity: 0).display, "93.00")
    }

    // MARK: - How rarity and lustre relate

    /// Rarity is no longer the item total.
    ///
    /// This test used to assert that it was — `rarity == round(rarityPoints)` — which held while
    /// lustre was a separate companion figure. It no longer is: the day is folded into rarity too,
    /// through `effort`, so that a settled user's days stop landing on the same number. The item
    /// total is still there and still the larger share; it is simply not the whole of it. See
    /// `RarityScoreTests` for the combination itself.
    @MainActor
    func testRarityIsItemLedButNotItemsAlone() {
        let traits = PawpetTraits(day: "2026-03-09", summary: day(), streakDays: 20)
        XCTAssertEqual(traits.rarity, Int(traits.rarityScore.rounded()))
        XCTAssertTrue(["S", "A", "B", "C", "D"].contains(traits.rarityGrade))
        // Items lead: seven tenths of the score, and the rest cannot exceed thirty points.
        XCTAssertGreaterThanOrEqual(traits.rarityScore, traits.rarityPoints * 0.70 - 0.01)
        XCTAssertLessThanOrEqual(traits.rarityScore, traits.rarityPoints * 0.70 + 30.01)
        // Lustre is still derived from the item total, never from the combined score — otherwise
        // the two would feed each other.
        XCTAssertEqual(traits.lustre.value,
                       CatLustre.compute(itemPoints: traits.rarityPoints, summary: day()).value)
    }
}
