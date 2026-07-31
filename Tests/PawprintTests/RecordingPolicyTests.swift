import XCTest
import PawprintCore
@testable import Pawprint

/// Section A of the characterization suite: what may be recorded, and when.
///
/// These are the privacy promises with a *timing* component — pausing stops recording, an excluded
/// application is not recorded from, a switched-off category is not collected. They could not be
/// tested before, not because the rule was complicated but because it lived on a 933-line
/// `@Observable` class that also owned the database, the clock and the statistics, so asking it a
/// question meant standing all of that up. `RecordingPolicy` is the same rule as a value.
final class RecordingPolicyTests: XCTestCase {

    private func settings(configure: (inout AppSettings) -> Void = { _ in }) -> AppSettings {
        var settings = AppSettings()
        settings.excludedApps = []
        configure(&settings)
        return settings
    }

    // MARK: - Pause

    func testPauseStopsEverything() {
        let policy = RecordingPolicy(settings: settings { $0.isPaused = true },
                                     frontmostBundleID: "com.microsoft.VSCode")
        XCTAssertFalse(policy.isRecordingActive)
        for category in [CollectionCategory.keyboard, .mouse, .appUsage,
                         .clipboard, .sleepWake, .powerPeripherals] {
            XCTAssertFalse(policy.allows(category), "\(category) was allowed while paused")
        }
    }

    func testUnpausedRecordsEverythingItIsAskedTo() {
        let policy = RecordingPolicy(settings: settings(), frontmostBundleID: "com.microsoft.VSCode")
        XCTAssertTrue(policy.isRecordingActive)
        for category in [CollectionCategory.keyboard, .mouse, .appUsage,
                         .clipboard, .sleepWake, .powerPeripherals] {
            XCTAssertTrue(policy.allows(category))
        }
    }

    // MARK: - Excluded applications

    func testAnExcludedAppStopsRecordingWhileItIsInFront() {
        let configured = settings {
            $0.excludedApps = [ExcludedApp(bundleID: "com.apple.Passwords", displayName: "Passwords")]
        }
        let inFront = RecordingPolicy(settings: configured, frontmostBundleID: "com.apple.Passwords")
        XCTAssertTrue(inFront.isCurrentAppExcluded)
        XCTAssertFalse(inFront.isRecordingActive)
        XCTAssertFalse(inFront.allows(.keyboard))

        // …and only while it is in front.
        let elsewhere = RecordingPolicy(settings: configured, frontmostBundleID: "com.microsoft.VSCode")
        XCTAssertFalse(elsewhere.isCurrentAppExcluded)
        XCTAssertTrue(elsewhere.isRecordingActive)
    }

    /// The window that is in front precisely when someone is doing something private.
    func testSystemProcessesAreNeverRecordedFrom() {
        for bundleID in ["com.apple.loginwindow", "com.apple.SecurityAgent",
                         "com.apple.ScreenSaver.Engine"] {
            let policy = RecordingPolicy(settings: settings(), frontmostBundleID: bundleID)
            XCTAssertTrue(policy.isExcluded(bundleID: bundleID), bundleID)
            XCTAssertFalse(policy.isRecordingActive, "recorded while \(bundleID) was in front")
        }
    }

    /// The exclusion list cannot be emptied into recording a system process.
    func testClearingTheExclusionListDoesNotExposeSystemProcesses() {
        let policy = RecordingPolicy(settings: settings { $0.excludedApps = [] },
                                     frontmostBundleID: "com.apple.loginwindow")
        XCTAssertFalse(policy.isRecordingActive)
    }

    func testNoFrontmostAppIsNotAnExclusion() {
        let policy = RecordingPolicy(settings: settings(), frontmostBundleID: nil)
        XCTAssertFalse(policy.isCurrentAppExcluded)
        XCTAssertTrue(policy.isRecordingActive)
    }

    // MARK: - Categories

    /// Each switch governs its own category and no other.
    func testEachCategorySwitchActsAlone() {
        let cases: [(CollectionCategory, (inout AppSettings) -> Void)] = [
            (.keyboard, { $0.collectKeyboard = false }),
            (.mouse, { $0.collectMouse = false }),
            (.appUsage, { $0.collectAppUsage = false }),
            (.clipboard, { $0.collectClipboard = false }),
            (.sleepWake, { $0.collectSleepWake = false }),
            (.powerPeripherals, { $0.collectPowerPeripherals = false }),
        ]
        for (switchedOff, configure) in cases {
            let policy = RecordingPolicy(settings: settings(configure: configure),
                                         frontmostBundleID: "com.microsoft.VSCode")
            XCTAssertFalse(policy.allows(switchedOff), "\(switchedOff) was still allowed")
            for other in cases.map(\.0) where other != switchedOff {
                XCTAssertTrue(policy.allows(other),
                              "switching off \(switchedOff) also stopped \(other)")
            }
        }
    }

    /// Pause outranks the category switches: everything off means everything off.
    func testPauseOutranksAnEnabledCategory() {
        let policy = RecordingPolicy(settings: settings {
            $0.isPaused = true
            $0.collectKeyboard = true
        }, frontmostBundleID: "com.microsoft.VSCode")
        XCTAssertFalse(policy.allows(.keyboard))
    }

    // MARK: - The gate as the app uses it

    /// The same rule, reached through `ActivityCenter`, because that is what the trackers call.
    @MainActor
    func testTheCentreDelegatesToTheSamePolicy() {
        let centre = ActivityCenter.shared
        let policy = centre.policy
        XCTAssertEqual(centre.isRecordingActive, policy.isRecordingActive)
        for category in [CollectionCategory.keyboard, .mouse, .appUsage,
                         .clipboard, .sleepWake, .powerPeripherals] {
            XCTAssertEqual(centre.isCategoryEnabled(category), policy.isCategoryEnabled(category))
        }
        XCTAssertEqual(centre.isExcluded(bundleID: "com.apple.loginwindow"),
                       policy.isExcluded(bundleID: "com.apple.loginwindow"))
    }
}
