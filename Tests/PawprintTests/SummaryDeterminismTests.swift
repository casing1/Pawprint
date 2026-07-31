import XCTest
import PawprintCore
@testable import Pawprint

/// That the same day gives the same answer twice.
///
/// Half a dozen figures were picked with `max` over a *dictionary*, or sorted by a key that ties.
/// Swift seeds its hashing per process and its sort is not stable, so on any day where two things
/// tie, the winner was whichever the hash table happened to visit first — and a different one after
/// the next launch. `bestFocusHour` on 2026-06-18 of the demo history really did alternate between
/// 11 and 13; it was found by checksumming every stored day six times and seeing one line move.
///
/// Nothing about that looks like a bug on screen. The number is plausible, it just isn't the same
/// number as yesterday.
final class SummaryDeterminismTests: XCTestCase {

    private let dayStart = Date(timeIntervalSince1970: 1_772_000_000)

    /// Two focus sessions of exactly equal length, in two different hours.
    private func dayWithTiedFocusHours() -> DailyRawCounters {
        var raw = DailyRawCounters(day: "2026-06-18")
        let calendar = Calendar.current
        let elevenAM = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: dayStart)!
        let onePM = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: dayStart)!
        raw.focusSessions = [
            FocusSessionRecord(start: elevenAM, end: elevenAM.addingTimeInterval(1_800), primaryApp: "A"),
            FocusSessionRecord(start: onePM, end: onePM.addingTimeInterval(1_800), primaryApp: "B"),
        ]
        return raw
    }

    /// The earlier hour wins. Which one it is matters less than that it is always the same one.
    func testTiedFocusHoursResolveToTheEarlier() {
        let summary = StatsEngine.summary(for: dayWithTiedFocusHours(), machine: .none)
        XCTAssertEqual(summary.bestFocusHour, 11)
    }

    /// Recomputing the same day must not move anything. This runs the whole summary, so it covers
    /// every figure at once rather than the handful known to have been at risk.
    func testTheWholeSummaryIsStableAcrossRepeatedComputation() {
        let raw = crowdedDay()
        let first = StatsEngine.summary(for: raw, machine: .none)
        for _ in 0..<20 {
            let again = StatsEngine.summary(for: raw, machine: .none)
            XCTAssertEqual(again.bestFocusHour, first.bestFocusHour)
            XCTAssertEqual(again.topInterruptingApp, first.topInterruptingApp)
            XCTAssertEqual(again.mostPressedKeyLabel, first.mostPressedKeyLabel)
            XCTAssertEqual(again.topApp?.bundleID, first.topApp?.bundleID)
            XCTAssertEqual(again.topTypingApp?.bundleID, first.topTypingApp?.bundleID)
            XCTAssertEqual(again.topClickingApp?.bundleID, first.topClickingApp?.bundleID)
            XCTAssertEqual(again.appUsage.map(\.bundleID), first.appUsage.map(\.bundleID))
            XCTAssertEqual(again.appInputProfiles.map(\.bundleID), first.appInputProfiles.map(\.bundleID))
            XCTAssertEqual(again.activityTags, first.activityTags)
            XCTAssertEqual(again.appsToReachHalfTime, first.appsToReachHalfTime)
            XCTAssertEqual(again.highlights.map(\.detail), first.highlights.map(\.detail))
            XCTAssertEqual(again.funFacts.map(\.text), first.funFacts.map(\.text))
        }
    }

    /// Each tie-break named explicitly, so the rule is documented rather than incidental.
    func testTiesAreBrokenByTheSmallerIdentifier() {
        var raw = crowdedDay()
        // Two apps, identical time.
        let start = dayStart
        raw.appSessions = [
            AppSessionRecord(bundleID: "com.zeta.app", appName: "Zeta",
                             start: start, end: start.addingTimeInterval(600)),
            AppSessionRecord(bundleID: "com.alpha.app", appName: "Alpha",
                             start: start, end: start.addingTimeInterval(600)),
        ]
        // Two apps, identical interruption counts.
        raw.focusInterruptionsByApp = ["com.zeta.app": 5, "com.alpha.app": 5]
        // Two keys, identical press counts.
        raw.keyCodeCounts = ["4": 100, "40": 100]
        // Two apps, identical input.
        raw.appKeyPresses = ["com.zeta.app": 50, "com.alpha.app": 50]
        raw.appClicks = [:]
        raw.appScrollPoints = [:]

        let summary = StatsEngine.summary(for: raw, machine: .none)
        XCTAssertEqual(summary.topApp?.bundleID, "com.alpha.app")
        XCTAssertEqual(summary.topInterruptingApp, "com.alpha.app")
        XCTAssertEqual(summary.appUsage.map(\.bundleID), ["com.alpha.app", "com.zeta.app"])
        XCTAssertEqual(summary.appInputProfiles.map(\.bundleID), ["com.alpha.app", "com.zeta.app"])
        XCTAssertEqual(summary.mostPressedKeyLabel, KeyboardLayout.label(for: 4),
                       "the lower key code should win a tie")
    }

    /// A day with enough going on that every tie-prone figure is actually computed.
    private func crowdedDay() -> DailyRawCounters {
        var raw = dayWithTiedFocusHours()
        let start = dayStart
        raw.totalKeyPresses = 9_000
        raw.characterKeyPresses = 7_000
        raw.activeSeconds = 5 * 3600
        raw.screenOnSeconds = 6 * 3600
        raw.leftClicks = 900
        raw.rightClicks = 60
        raw.keyCodeCounts = ["0": 400, "4": 400, "49": 900, "40": 400]
        raw.keyCategoryCounts = [KeyCategory.character.rawValue: 7_000,
                                 KeyCategory.space.rawValue: 900]
        raw.appSessions = [
            AppSessionRecord(bundleID: "com.b.app", appName: "B", start: start,
                             end: start.addingTimeInterval(3_600)),
            AppSessionRecord(bundleID: "com.a.app", appName: "A",
                             start: start.addingTimeInterval(3_600),
                             end: start.addingTimeInterval(7_200)),
        ]
        raw.appKeyPresses = ["com.a.app": 3_500, "com.b.app": 3_500]
        raw.appClicks = ["com.a.app": 450, "com.b.app": 450]
        raw.focusInterruptionsByApp = ["com.a.app": 4, "com.b.app": 4]
        raw.totalAppSwitches = 40
        raw.firstActivity = start
        raw.lastActivity = start.addingTimeInterval(6 * 3600)
        for minute in 540..<600 { raw.charKeysPerMinute[minute] = 100 }
        for minute in 540..<600 { raw.activityPerMinute[minute] = 120 }
        return raw
    }
}
