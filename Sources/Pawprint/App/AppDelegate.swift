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

        if settings.updateCheckEnabled, settings.updateCheckAutomatically, !settings.updateFeedURL.isEmpty {
            Task { @MainActor in
                // Let launch settle before touching the network.
                try? await Task.sleep(for: .seconds(6))
                await UpdateChecker.shared.check(feedURL: settings.updateFeedURL, manual: false)
            }
        }

        // End-to-end exercise of the update pipeline: check → download → ditto → signature
        // verification → swap. There is no other way to prove the install path works, since it
        // replaces the running bundle and can't be unit-tested in-process.
        if let feed = ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_TEST"] {
            Task { @MainActor in DebugSnapshot.runUpdateFlow(feed: feed) }
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
