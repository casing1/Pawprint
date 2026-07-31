import XCTest
import PawprintCore
@testable import Pawprint

/// That a comparison is measured against something the reader can picture.
///
/// The failure this guards against is silent and specific: the language pack says "Zugspitze" while
/// the arithmetic still divides by Hallasan's 1,947 m, so the sentence is in German and the number
/// is wrong. Nothing about that looks broken on screen. The referent and the figure have to move
/// together, and these are the checks that they did.
final class RegionalReferenceTests: XCTestCase {

    private let all: [(String, RegionalReferences)] = [
        ("ko", .korean), ("en", .english), ("ja", .japanese), ("de", .german),
    ]

    /// Every offered language resolves to its own set — nothing quietly falls through to English.
    func testEachLanguageHasItsOwnReferences() {
        for (code, expected) in all {
            XCTAssertEqual(RegionalReferences.forLanguage(code), expected, code)
        }
        for (a, b) in [("ko", "en"), ("ko", "ja"), ("ko", "de"), ("en", "ja"), ("en", "de"), ("ja", "de")] {
            XCTAssertNotEqual(RegionalReferences.forLanguage(a), RegionalReferences.forLanguage(b),
                              "\(a) and \(b) share a referent set")
        }
    }

    /// An unknown code follows the same fallback the language packs do.
    func testUnknownLanguagesFallBackToEnglish() {
        for code in ["", "fr", "zh-Hans", "xx"] {
            XCTAssertEqual(RegionalReferences.forLanguage(code), .english, code)
        }
    }

    /// The four towers are slots, not names: a set whose "small" tower is taller than its "huge" one
    /// would put the percentages in the wrong order and make a light day look enormous.
    func testTowersAscendAndMountainsOutrankThem() {
        for (code, r) in all {
            XCTAssertLessThan(r.towerSmall, r.towerMedium, code)
            XCTAssertLessThan(r.towerMedium, r.towerLarge, code)
            XCTAssertLessThan(r.towerLarge, r.towerHuge, code)
            XCTAssertLessThan(r.towerHuge, r.mountainMedium, code)
            XCTAssertLessThan(r.mountainMedium, r.mountainLarge, code)
            // Everest is not regional, and nothing regional may overtake it.
            XCTAssertLessThan(r.mountainLarge, 8_848, code)
        }
    }

    /// The electricity line is gated on the value reading above 1, so a locale quoting whole dollars
    /// would simply never show it. Whatever unit each pack names, the figure has to land in the same
    /// band Korean won already does.
    func testElectricityPriceStaysInAReadableBand() {
        for (code, r) in all {
            XCTAssertGreaterThanOrEqual(r.currencyPerKWh, 10, "\(code): too small to ever clear the gate")
            XCTAssertLessThanOrEqual(r.currencyPerKWh, 1_000, "\(code): implausible per kWh")
        }
    }

    /// Grid intensity is a real measurement, not a knob — these are national averages and should
    /// stay within sight of each other.
    func testGridIntensityIsPlausible() {
        for (code, r) in all {
            XCTAssertGreaterThan(r.gramsCO2PerKWh, 100, code)
            XCTAssertLessThan(r.gramsCO2PerKWh, 900, code)
        }
    }

    func testEveryLocaleHasAnIntercityRouteAndASheetOfPaper() {
        for (code, r) in all {
            XCTAssertGreaterThan(r.intercityRoute, 100_000, code)
            XCTAssertLessThan(r.intercityRoute, 3_000_000, code)
            XCTAssertGreaterThanOrEqual(r.manuscriptSheetChars, 100, code)
            XCTAssertLessThanOrEqual(r.manuscriptSheetChars, 1_800, code)
        }
    }

    /// Korean is what every figure the app has ever shipped was computed against, and it must not
    /// have moved. These are the literals that were in `FunConversions` before the split.
    func testKoreanReferencesAreUnchanged() {
        let r = RegionalReferences.korean
        XCTAssertEqual(r.towerSmall, 236)         // 남산타워
        XCTAssertEqual(r.towerMedium, 249)        // 63빌딩
        XCTAssertEqual(r.towerLarge, 330)         // 에펠탑
        XCTAssertEqual(r.towerHuge, 555)          // 롯데월드타워
        XCTAssertEqual(r.mountainMedium, 1_947)   // 한라산
        XCTAssertEqual(r.mountainLarge, 2_744)    // 백두산
        XCTAssertEqual(r.intercityRoute, 325_000) // 서울–부산
        XCTAssertEqual(r.gramsCO2PerKWh, 459)
        XCTAssertEqual(r.currencyPerKWh, 130)
        XCTAssertEqual(r.manuscriptSheetChars, 200)
    }

    /// The point of the whole exercise: the same day is measured against something else, so it
    /// produces a different set of comparisons.
    ///
    /// The rendered numbers can't be read here — under `swift test` there is no bundle to load a
    /// pack from, so `L10n.t` hands back the key and swallows its arguments. What *is* observable
    /// is which comparisons clear their "is this readable" gate, and that is decided by the
    /// referent: 20 m of scrolling is 5.4% of the Berliner Fernsehturm and only 3.6% of Lotte
    /// World Tower, so Germany gets the line about its tallest tower and Korea does not.
    func testTheSameScrollingProducesADifferentSetOfComparisons() {
        func facts(_ r: RegionalReferences) -> [FunFact] {
            FunConversions.scrollFacts(screens: 100, screenHeightMeters: 0.2, references: r)
        }
        XCTAssertEqual(facts(.korean).count, 5)
        XCTAssertEqual(facts(.german).count, 6)
        XCTAssertEqual(facts(.korean).map(\.text).filter { $0.contains("9bbfbe7a") }.count, 0)
        XCTAssertEqual(facts(.german).map(\.text).filter { $0.contains("9bbfbe7a") }.count, 1)
    }

    /// A cursor that has travelled a fixed distance is a different fraction of Seoul–Busan than of
    /// Berlin–München, and the text has to say so.
    func testTheIntercityFractionFollowsTheRoute() {
        func percentage(_ r: RegionalReferences) -> Double {
            1_000 / r.intercityRoute * 100
        }
        XCTAssertGreaterThan(percentage(.korean), percentage(.german),
                             "the shorter route must be the larger fraction")
        XCTAssertEqual(percentage(.korean), 0.3077, accuracy: 0.0001)
        XCTAssertEqual(percentage(.german), 0.1709, accuracy: 0.0001)
    }
}
