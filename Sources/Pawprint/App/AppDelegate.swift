import AppKit
import PawprintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Not `private` only because the debug commands drive the popover to take screenshots.
    /// Nothing else reaches for it.
    lazy var statusItemController = StatusItemController()

    /// What the application is made of. Built once, here, and nowhere else — see `AppEnvironment`.
    let environment = AppEnvironment.live

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPolicy()
        environment.start()
        statusItemController.install()

        // Re-arm the daily recap on every launch: the scheduled body carries the day's numbers,
        // so it needs refreshing rather than surviving from a previous run.
        let settings = environment.activityCenter.settings
        if settings.dailySummaryEnabled {
            Task { @MainActor in
                await NotificationManager.shared.scheduleDailySummary(
                    hour: settings.dailySummaryHour,
                    minute: settings.dailySummaryMinute,
                    summary: environment.activityCenter.todaySummary
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

        // Screenshot capture, GIF rendering, demo seeding and the probe suite. Compiled out
        // of a release build entirely — see `DebugCommand`.
        #if DEBUG
        DebugCommand.runIfRequested(self)
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController.remove()
        MenuBarIconAnimator.shared.stop()
        TrackingCoordinator.shared.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applyDockIconPolicy() {
        NSApp.setActivationPolicy(ActivityCenter.shared.settings.showDockIcon ? .regular : .accessory)
    }
}
