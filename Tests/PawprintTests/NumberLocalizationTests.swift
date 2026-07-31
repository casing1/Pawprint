import XCTest
import PawprintCore
@testable import Pawprint

/// That a number means the same thing to the person reading it as to the code that wrote it.
///
/// "1,500" is fifteen hundred in Korean, English and Japanese, and one and a half in German. A
/// formatter following the *system* locale instead of the chosen language gets this wrong in a way
/// that looks completely normal — the digits are right, the magnitude is off by a thousand.
final class NumberLocalizationTests: XCTestCase {

    /// Swaps the active pack for the duration of one check. There is no pack to load under
    /// `swift test`, and none is needed: everything here reads the language *code*.
    private func withLanguage(_ code: String, _ body: () -> Void) {
        let previous = Tables.activeCode
        Tables.setActive([:], code: code)
        body()
        Tables.setActive([:], code: previous)
    }

    func testGroupingFollowsTheChosenLanguage() {
        for code in ["ko", "en", "ja"] {
            withLanguage(code) {
                XCTAssertEqual(Formatters.groupedNumber(1_500), "1,500", code)
                XCTAssertEqual(Formatters.groupedNumber(40_000), "40,000", code)
            }
        }
        withLanguage("de") {
            XCTAssertEqual(Formatters.groupedNumber(1_500), "1.500")
            XCTAssertEqual(Formatters.groupedNumber(40_000), "40.000")
        }
    }

    func testTheDecimalMarkFollowsTheChosenLanguage() {
        for code in ["ko", "en", "ja"] {
            withLanguage(code) {
                XCTAssertEqual(Formatters.decimalSeparator, ".", code)
                XCTAssertEqual(Formatters.decimalText(22.24, places: 1), "22.2", code)
            }
        }
        withLanguage("de") {
            XCTAssertEqual(Formatters.decimalSeparator, ",")
            XCTAssertEqual(Formatters.decimalText(22.24, places: 1), "22,2")
        }
    }

    /// The dates in the popover header come from the same place, and this is what left a fully
    /// translated German build printing "31. Jul (Fri)".
    func testTheDateLocaleFollowsTheChosenLanguage() {
        let expected = ["ko": "ko_KR", "en": "en_US", "ja": "ja_JP", "de": "de_DE"]
        for (code, identifier) in expected {
            withLanguage(code) {
                XCTAssertEqual(LocalizationManager.activeLocale.identifier, identifier, code)
            }
        }
    }

    /// An unknown language falls back the same way the packs do.
    func testAnUnknownLanguageFormatsAsEnglish() {
        withLanguage("fr") {
            XCTAssertEqual(LocalizationManager.activeLocale.identifier, "en_US")
            XCTAssertEqual(Formatters.groupedNumber(1_500), "1,500")
        }
    }

    /// Korean is what every figure the app has shipped was formatted as, and it must not move.
    func testKoreanFormattingIsUnchanged() {
        withLanguage("ko") {
            XCTAssertEqual(Formatters.groupedNumber(1_234_567), "1,234,567")
            XCTAssertEqual(Formatters.decimalText(1.4, places: 2), "1.40")
            XCTAssertEqual(Formatters.decimalText(3.14159, places: 1), "3.1")
        }
    }
}
