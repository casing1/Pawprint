import AppKit
import XCTest
@testable import Pawprint

@MainActor
final class AdventureIsolationTests: XCTestCase {

    func testPawprintOwnProcessIsAlwaysExcludedFromTracking() {
        XCTAssertTrue(
            ActivityCenter.isOwnProcess(
                bundleID: "com.pawprint.app",
                runningBundleID: nil
            )
        )
        XCTAssertTrue(
            ActivityCenter.isOwnProcess(
                bundleID: "dev.pawprint.local",
                runningBundleID: "dev.pawprint.local"
            )
        )
        XCTAssertFalse(
            ActivityCenter.isOwnProcess(
                bundleID: "com.apple.dt.Xcode",
                runningBundleID: "dev.pawprint.local"
            )
        )
        XCTAssertTrue(
            ActivityCenter.shouldExclude(
                bundleID: "com.pawprint.app",
                runningBundleID: nil,
                isUserExcluded: false
            )
        )
        XCTAssertTrue(
            ActivityCenter.shouldExclude(
                bundleID: "example.private",
                runningBundleID: "dev.pawprint.local",
                isUserExcluded: true
            )
        )
        XCTAssertFalse(
            ActivityCenter.shouldExclude(
                bundleID: "com.apple.dt.Xcode",
                runningBundleID: "dev.pawprint.local",
                isUserExcluded: false
            )
        )
    }

    func testClosingAdventureWindowReleasesHostedContent() {
        let window = NSWindow()
        window.contentViewController = NSViewController()

        AdventureWindowController.releaseContent(
            from: Notification(
                name: NSWindow.willCloseNotification,
                object: window
            )
        )

        XCTAssertNil(window.contentViewController)
    }

    func testDockPolicyKeepsNormalWindowsReachable() {
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: false,
                hasVisibleTitledWindow: true
            ),
            .regular
        )
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: false,
                hasVisibleTitledWindow: false
            ),
            .accessory
        )
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: true,
                hasVisibleTitledWindow: false
            ),
            .regular
        )
    }

    func testSwiftUISettingsSceneInjectsTheAppEnvironment() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repository.appendingPathComponent(
                "Sources/Pawprint/App/PawprintApp.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("SettingsRootView()\n                .pawprintEnvironment()"),
            "The system-owned Settings scene must inject ActivityCenter before restoration renders it"
        )
    }

    func testMenuBarAnimationIsCappedAtEightFramesPerSecond() {
        let sampleWPMValues: [Double] = [0, 5, 20, 35, 55, 90]

        for wpm in sampleWPMValues {
            XCTAssertGreaterThanOrEqual(
                MenuBarIconAnimator.frameInterval(forWPM: wpm),
                MenuBarIconAnimator.minimumActiveFrameInterval
            )
        }
        XCTAssertEqual(
            MenuBarIconAnimator.minimumActiveFrameInterval,
            0.125,
            accuracy: 0.000_001
        )
    }

    func testAdventurePreservesPawprintPopoverDimensions() {
        XCTAssertEqual(PopoverRootView.contentWidth, 380)
        XCTAssertEqual(PopoverRootView.defaultScrollHeight, 520)
    }

    func testAdventureDoesNotAddAControlToPawprintTopBar() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let popoverSource = try String(
            contentsOf: repository.appendingPathComponent(
                "Sources/Pawprint/UI/PopoverRootView.swift"
            ),
            encoding: .utf8
        )
        let gallerySource = try String(
            contentsOf: repository.appendingPathComponent(
                "Sources/Pawprint/UI/PawpetGalleryView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(
            popoverSource.contains("Image(systemName: \"map.fill\")"),
            "Adventure belongs behind the Gallery entry, not in Pawprint's compact top bar"
        )
        XCTAssertTrue(
            gallerySource.contains("browseButton(L10n.t(\"adventure.button\")"),
            "Removing the top-bar control must not make Adventure unreachable"
        )
    }

    func testAdventurePresentationHasNoPerpetualAnimation() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Sources/Pawprint/UI/Adventure/AdventureBattleView.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionHUDView.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionDetailView.swift",
            "Sources/Pawprint/UI/Adventure/SunlitWispView.swift",
        ]

        for path in paths {
            let source = try String(
                contentsOf: repository.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertFalse(
                source.contains("repeatForever"),
                "\(path) must become idle while waiting for the next turn"
            )
        }
    }

    func testSnapshotHarnessRequiresAnExplicitSeparateDatabase() throws {
        XCTAssertNil(try AdventureSnapshotHarness.configuration(environment: [:]))

        XCTAssertThrowsError(
            try AdventureSnapshotHarness.configuration(
                environment: ["PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.png"]
            )
        ) { error in
            XCTAssertEqual(error as? AdventureSnapshotHarnessError, .missingDatabase)
        }

        XCTAssertThrowsError(
            try AdventureSnapshotHarness.configuration(
                environment: [
                    "PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.sqlite3",
                    "PAWPRINT_DB": "/tmp/./adventure.sqlite3",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? AdventureSnapshotHarnessError, .outputMatchesDatabase)
        }

        let environment = [
            "PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.png",
            "PAWPRINT_DB": "/tmp/adventure.sqlite3",
            "PAWPRINT_ADVENTURE_AUTORUN": "1",
        ]
        XCTAssertEqual(
            try AdventureSnapshotHarness.configuration(environment: environment),
            AdventureSnapshotConfiguration(
                outputPath: "/tmp/adventure.png",
                databasePath: "/tmp/adventure.sqlite3"
            )
        )
        XCTAssertTrue(AdventureSnapshotHarness.shouldAutorun(environment: environment))
        XCTAssertFalse(
            AdventureSnapshotHarness.shouldAutorun(
                environment: ["PAWPRINT_ADVENTURE_AUTORUN": "1"]
            )
        )
    }
}
