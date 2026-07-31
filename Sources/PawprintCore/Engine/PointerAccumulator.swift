import Foundation

/// What the mouse and trackpad do to a day.
///
/// Clicks, cursor travel and scrolling, none of which keeps state between events — the numbers only
/// ever go up. It is here for the same reason as the keyboard's: so the arithmetic can be checked
/// without a running application, and so the one place a click turns into a statistic is a place
/// you can point at.
///
/// Cursor movement is a *distance*, never a route, and scrolling is a *magnitude*, never a
/// position. There is nowhere in this type for a path to be accumulated, which is deliberate.
package struct PointerAccumulator {

    package init() {}

    package mutating func recordClick(kind: ClickKind,
                                      minute: Int,
                                      frontmostBundleID: String?,
                                      into counters: inout DailyRawCounters) {
        switch kind {
        case .left: counters.leftClicks += 1
        case .right: counters.rightClicks += 1
        case .double: counters.doubleClicks += 1
        case .drag: counters.dragCount += 1
        }
        counters.clicksPerMinute[minute] += 1
        counters.activityPerMinute[minute] += 1
        if let bundleID = frontmostBundleID {
            counters.appClicks[bundleID, default: 0] += 1
        }
    }

    /// A drag is a click that is already being counted as movement, so it does not add to the
    /// session's click tally the menu bar shows.
    package func countsTowardsSessionClicks(_ kind: ClickKind) -> Bool { kind != .drag }

    package mutating func recordCursorMovement(distancePixels: Double,
                                               speedPxPerSec: Double,
                                               into counters: inout DailyRawCounters) {
        counters.cursorDistancePixels += distancePixels
        counters.maxCursorSpeedPxPerSec = max(counters.maxCursorSpeedPxPerSec, speedPxPerSec)
    }

    package mutating func recordScroll(deltaY: Double,
                                       deltaX: Double,
                                       speedPointsPerSec: Double,
                                       minute: Int,
                                       frontmostBundleID: String?,
                                       into counters: inout DailyRawCounters) {
        if deltaY > 0 { counters.scrollUpPoints += deltaY }
        if deltaY < 0 { counters.scrollDownPoints += -deltaY }
        if deltaX != 0 { counters.scrollHorizontalPoints += abs(deltaX) }
        counters.maxScrollSpeedPointsPerSec = max(counters.maxScrollSpeedPointsPerSec,
                                                  speedPointsPerSec)

        let magnitude = abs(deltaY) + abs(deltaX)
        counters.scrollPerMinute[minute] += magnitude
        counters.activityPerMinute[minute] += 1
        if let bundleID = frontmostBundleID {
            counters.appScrollPoints[bundleID, default: 0] += magnitude
        }
    }

    package mutating func recordScrollDirectionChange(into counters: inout DailyRawCounters) {
        counters.scrollDirectionChanges += 1
    }
}
