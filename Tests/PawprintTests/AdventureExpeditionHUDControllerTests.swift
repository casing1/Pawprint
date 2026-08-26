import AppKit
import XCTest
@testable import Pawprint

@MainActor
final class AdventureExpeditionHUDControllerTests: XCTestCase {
    func testExpandedFrameKeepsTopRightCornerAnchored() {
        let compact = NSRect(x: 900, y: 500, width: 292, height: 302)

        let expanded = AdventureExpeditionHUDController.frame(
            keepingTopRightOf: compact,
            contentSize: .init(width: 480, height: 420),
            within: NSRect(x: 0, y: 0, width: 1600, height: 1000)
        )

        XCTAssertEqual(expanded.maxX, compact.maxX)
        XCTAssertEqual(expanded.maxY, compact.maxY)
        XCTAssertEqual(expanded.size, NSSize(width: 480, height: 420))
    }

    func testExpandedFrameClampsToVisibleScreenMargin() {
        let compact = NSRect(x: 8, y: 4, width: 292, height: 302)
        let visible = NSRect(x: 0, y: 0, width: 800, height: 600)

        let expanded = AdventureExpeditionHUDController.frame(
            keepingTopRightOf: compact,
            contentSize: .init(width: 480, height: 420),
            within: visible
        )

        XCTAssertEqual(expanded.minX, 10)
        XCTAssertEqual(expanded.minY, 10)
        XCTAssertLessThanOrEqual(expanded.maxX, visible.maxX - 10)
        XCTAssertLessThanOrEqual(expanded.maxY, visible.maxY - 10)
    }

    func testExpandedSizeFitsSmallVisibleFrame() {
        let fitted = AdventureExpeditionHUDController.fittedContentSize(
            .init(width: 480, height: 420),
            within: NSRect(x: 0, y: 0, width: 430, height: 370)
        )

        XCTAssertEqual(fitted, NSSize(width: 410, height: 350))
    }
}
