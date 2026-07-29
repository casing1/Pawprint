import XCTest
import PawprintCore
@testable import Pawprint

final class SmokeTests: XCTestCase {
    func testDayKeyIsReachableFromTests() {
        XCTAssertEqual(DayKey.addingDays(1, to: "2026-03-09"), "2026-03-10")
    }
}
