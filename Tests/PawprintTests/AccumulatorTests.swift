import XCTest
import PawprintCore
@testable import Pawprint

/// Section C: what a keystroke, a click and a scroll actually do to a day.
///
/// These could not be written before. The arithmetic lived on the same 900-line class as the
/// database handle and the day-rollover cursor, so checking whether a three-second gap continues a
/// typing streak meant driving a running application and hoping.
final class AccumulatorTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_772_000_000)
    private func day() -> DailyRawCounters { DailyRawCounters(day: "2026-03-09") }

    // MARK: - Keyboard

    func testAKeyPressCountsInEveryPlaceItShould() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        keyboard.recordKeyPress(category: .character, keyCode: 4, at: start, minute: 540,
                                frontmostBundleID: "com.microsoft.VSCode", into: &counters)

        XCTAssertEqual(counters.totalKeyPresses, 1)
        XCTAssertEqual(counters.characterKeyPresses, 1)
        XCTAssertEqual(counters.keyCategoryCounts[KeyCategory.character.rawValue], 1)
        XCTAssertEqual(counters.keyCodeCounts["4"], 1)
        XCTAssertEqual(counters.activityPerMinute[540], 1)
        XCTAssertEqual(counters.charKeysPerMinute[540], 1)
        XCTAssertEqual(counters.appKeyPresses["com.microsoft.VSCode"], 1)
    }

    /// A modifier is a key press but not a character: it must not reach the character counters or
    /// start a typing streak.
    func testANonCharacterKeyIsCountedButIsNotTyping() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        keyboard.recordKeyPress(category: .shift, keyCode: 56, at: start, minute: 540,
                                frontmostBundleID: nil, into: &counters)

        XCTAssertEqual(counters.totalKeyPresses, 1)
        XCTAssertEqual(counters.characterKeyPresses, 0)
        XCTAssertEqual(counters.charKeysPerMinute[540], 0)
        XCTAssertEqual(counters.typingSessionCount, 0)
        XCTAssertEqual(counters.maxWPM, 0)
    }

    func testNoFrontmostAppMeansNoAttribution() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        keyboard.recordKeyPress(category: .character, keyCode: 4, at: start, minute: 540,
                                frontmostBundleID: nil, into: &counters)
        XCTAssertTrue(counters.appKeyPresses.isEmpty)
        XCTAssertEqual(counters.totalKeyPresses, 1)
    }

    // MARK: - Typing streaks

    /// Gaps under the threshold continue the streak; the recorded length is the longest one.
    func testAContinuousRunIsOneStreak() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<21 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 2), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertEqual(counters.typingSessionCount, 1)
        XCTAssertEqual(counters.longestTypingStreakSeconds, 40)
    }

    /// A gap longer than the threshold starts a new one, and the first streak's length survives.
    func testALongGapStartsANewStreakAndKeepsTheLongest() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<11 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 2), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        // Well past the three-second threshold.
        for i in 0..<3 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(300 + Double(i) * 2), minute: 545,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertEqual(counters.typingSessionCount, 2)
        XCTAssertEqual(counters.longestTypingStreakSeconds, 20, "the shorter second run overwrote it")
    }

    /// Exactly at the threshold still counts as continuous.
    func testTheStreakThresholdIsInclusive() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        keyboard.recordKeyPress(category: .character, keyCode: 4, at: start, minute: 540,
                                frontmostBundleID: nil, into: &counters)
        keyboard.recordKeyPress(category: .character, keyCode: 4,
                                at: start.addingTimeInterval(KeyboardAccumulator.streakGapSeconds),
                                minute: 540, frontmostBundleID: nil, into: &counters)
        XCTAssertEqual(counters.typingSessionCount, 1)
    }

    // MARK: - Live WPM

    /// Five characters to a word over a sixty-second window.
    func testLiveWPMCountsTheTrailingMinute() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        // 100 characters, one every half second: 50 seconds, all inside the window.
        for i in 0..<100 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 0.5), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertEqual(keyboard.liveWPM, 20, accuracy: 0.001)
    }

    /// Keystrokes older than the window stop counting.
    func testTheWindowExpires() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<50 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 0.2), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertGreaterThan(keyboard.liveWPM, 0)
        keyboard.refreshLiveWPM(at: start.addingTimeInterval(120))
        XCTAssertEqual(keyboard.liveWPM, 0, "nothing typed for two minutes is not a speed")
    }

    /// Fewer than five keystrokes is not a record, however fast they arrive.
    func testAHandfulOfKeysIsNotAPersonalBest() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<4 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 0.01), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertEqual(counters.maxWPM, 0)
    }

    func testMaxWPMKeepsTheMinuteItHappenedIn() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<30 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 0.3), minute: 615,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertGreaterThan(counters.maxWPM, 0)
        XCTAssertEqual(counters.maxWPMMinute, 615)
    }

    /// The window is trimmed rather than rescanned, so a long burst must not lose entries.
    func testABurstDoesNotDropKeystrokesFromTheWindow() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        // 600 keys over 60 seconds: every one is inside the window at the end.
        for i in 0..<600 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i) * 0.1), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        XCTAssertEqual(keyboard.liveWPM, 600 / 5, accuracy: 0.5)
    }

    func testResetEndsTheStreakAndEmptiesTheWindow() {
        var counters = day()
        var keyboard = KeyboardAccumulator()
        for i in 0..<10 {
            keyboard.recordKeyPress(category: .character, keyCode: 4,
                                    at: start.addingTimeInterval(Double(i)), minute: 540,
                                    frontmostBundleID: nil, into: &counters)
        }
        keyboard.reset()
        XCTAssertEqual(keyboard.liveWPM, 0)

        var tomorrow = DailyRawCounters(day: "2026-03-10")
        keyboard.recordKeyPress(category: .character, keyCode: 4,
                                at: start.addingTimeInterval(11), minute: 0,
                                frontmostBundleID: nil, into: &tomorrow)
        XCTAssertEqual(tomorrow.typingSessionCount, 1, "yesterday's streak carried over")
    }

    // MARK: - Pointer

    func testEachClickKindLandsInItsOwnCounter() {
        var counters = day()
        var pointer = PointerAccumulator()
        for (kind, expected) in [(ClickKind.left, \DailyRawCounters.leftClicks),
                                 (.right, \.rightClicks),
                                 (.double, \.doubleClicks),
                                 (.drag, \.dragCount)] {
            var single = day()
            pointer.recordClick(kind: kind, minute: 540, frontmostBundleID: nil, into: &single)
            XCTAssertEqual(single[keyPath: expected], 1, "\(kind)")
        }
        pointer.recordClick(kind: .left, minute: 540, frontmostBundleID: "com.google.Chrome",
                            into: &counters)
        XCTAssertEqual(counters.clicksPerMinute[540], 1)
        XCTAssertEqual(counters.activityPerMinute[540], 1)
        XCTAssertEqual(counters.appClicks["com.google.Chrome"], 1)
    }

    /// A drag is already counted as movement, so it does not also count as a session click.
    func testADragIsNotASessionClick() {
        let pointer = PointerAccumulator()
        XCTAssertFalse(pointer.countsTowardsSessionClicks(.drag))
        for kind in [ClickKind.left, .right, .double] {
            XCTAssertTrue(pointer.countsTowardsSessionClicks(kind))
        }
    }

    func testCursorTravelAccumulatesAndKeepsItsPeak() {
        var counters = day()
        var pointer = PointerAccumulator()
        pointer.recordCursorMovement(distancePixels: 100, speedPxPerSec: 500, into: &counters)
        pointer.recordCursorMovement(distancePixels: 250, speedPxPerSec: 200, into: &counters)
        XCTAssertEqual(counters.cursorDistancePixels, 350)
        XCTAssertEqual(counters.maxCursorSpeedPxPerSec, 500, "a slower move lowered the peak")
    }

    /// Up and down are separate totals, and both are magnitudes — direction is in which counter it
    /// lands in, never in a sign.
    func testScrollSplitsByDirection() {
        var counters = day()
        var pointer = PointerAccumulator()
        pointer.recordScroll(deltaY: 120, deltaX: 0, speedPointsPerSec: 900, minute: 540,
                             frontmostBundleID: nil, into: &counters)
        pointer.recordScroll(deltaY: -80, deltaX: 0, speedPointsPerSec: 300, minute: 540,
                             frontmostBundleID: nil, into: &counters)
        pointer.recordScroll(deltaY: 0, deltaX: -45, speedPointsPerSec: 100, minute: 540,
                             frontmostBundleID: nil, into: &counters)

        XCTAssertEqual(counters.scrollUpPoints, 120)
        XCTAssertEqual(counters.scrollDownPoints, 80)
        XCTAssertEqual(counters.scrollHorizontalPoints, 45)
        XCTAssertGreaterThanOrEqual(counters.scrollDownPoints, 0)
        XCTAssertEqual(counters.maxScrollSpeedPointsPerSec, 900)
        XCTAssertEqual(counters.scrollPerMinute[540], 245, accuracy: 0.001)
        XCTAssertEqual(counters.activityPerMinute[540], 3)
    }

    func testScrollIsAttributedToTheAppInFront() {
        var counters = day()
        var pointer = PointerAccumulator()
        pointer.recordScroll(deltaY: 200, deltaX: 0, speedPointsPerSec: 400, minute: 540,
                             frontmostBundleID: "com.google.Chrome", into: &counters)
        XCTAssertEqual(counters.appScrollPoints["com.google.Chrome"], 200)
    }
}
