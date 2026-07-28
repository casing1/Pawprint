import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItemController = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPolicy()
        TrackingCoordinator.shared.start()
        PawAnimator.shared.start()
        statusItemController.install()

        // Re-arm the daily recap on every launch: the scheduled body carries the day's numbers,
        // so it needs refreshing rather than surviving from a previous run.
        let settings = ActivityCenter.shared.settings
        if settings.dailySummaryEnabled {
            Task { @MainActor in
                await NotificationManager.shared.scheduleDailySummary(
                    hour: settings.dailySummaryHour,
                    minute: settings.dailySummaryMinute,
                    summary: ActivityCenter.shared.todaySummary
                )
            }
        }
        // First run: nothing works without Accessibility + Input Monitoring, and macOS shows its
        // own prompts exactly once. Walk the user through it rather than reporting zeros forever.
        if !settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingWindowController.shared.present()
            }
        }

        UpdateChecker.shared.startPeriodicChecks(settings: settings)

        // End-to-end exercise of the update pipeline: check → download → ditto → signature
        // verification → swap. There is no other way to prove the install path works, since it
        // replaces the running bundle and can't be unit-tested in-process.
        if ProcessInfo.processInfo.environment["PAWPRINT_RECORD_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeRecordCelebration() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeAutomaticUpdate() }
        }

        if let feed = ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_TEST"] {
            Task { @MainActor in DebugSnapshot.runUpdateFlow(feed: feed) }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_DMG_BG"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderDMGBackground(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_BANNER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderBanner(); NSApp.terminate(nil)
            }
        }

        // Opens Settings so its window can be screenshotted; SwiftUI's TabView renders as a
        // placeholder in ImageRenderer, so a real window is the only way to check the tab bar.
        if let language = ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                var updated = ActivityCenter.shared.settings
                updated.language = language == "en" ? .english : .korean
                ActivityCenter.shared.updateSettings(updated)
                if ProcessInfo.processInfo.environment["PAWPRINT_FORCE_STALL"] != nil {
                    PermissionsManager.shared.setKeyboardEventsStalled(true)
                }
                SettingsOpener.open()
                if ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS_SHOT"] != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        DebugSnapshot.captureSettingsWindow()
                    }
                }
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SWITCH"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { DebugSnapshot.probeLanguageSwitch() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_CLIPBOARD"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { DebugSnapshot.probeClipboard() }
        }

        // Opens the item catalog in a real window so the hover magnifier can be driven with a
        // synthetic mouse move and screenshotted — ImageRenderer has no pointer.
        if ProcessInfo.processInfo.environment["PAWPRINT_ITEMS_WINDOW"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.openItemCatalogWindow() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_KEYS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeKeyboardDelivery() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_REWARDS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeRecordRewards() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_ITEMS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeItemCatalog() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_L10N"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.auditLocalization() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_WALL"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderCatWall(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SHOWCASE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderShowcase(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_TITLES"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                DebugSnapshot.runTitleReport(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeSettings() }
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_PAWPETS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderPawpetSheet(); NSApp.terminate(nil)
            }
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_SNAPSHOT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { DebugSnapshot.run(); NSApp.terminate(nil) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController.remove()
        PawAnimator.shared.stop()
        TrackingCoordinator.shared.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applyDockIconPolicy() {
        NSApp.setActivationPolicy(ActivityCenter.shared.settings.showDockIcon ? .regular : .accessory)
    }
}
