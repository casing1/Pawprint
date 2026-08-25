import AppKit
import PawprintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Not `private` only because the debug commands drive the popover to take screenshots.
    /// Nothing else reaches for it.
    lazy var statusItemController = StatusItemController()

    /// What the application is made of. Delayed until launch so debug database guards can run
    /// before `PawprintStore.shared` is allowed to open either the override or the user's store.
    lazy var environment = AppEnvironment.live

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Validate the Adventure capture hook before AppEnvironment initializes the real store.
        let adventureSnapshot: AdventureSnapshotConfiguration?
        do {
            adventureSnapshot = try AdventureSnapshotHarness.configuration()
        } catch {
            FileHandle.standardError.write(
                "ADVENTURE SNAPSHOT REFUSED: \(error)\n".data(using: .utf8)!
            )
            NSApp.terminate(nil)
            return
        }
        #endif

        applyDockIconPolicy()
        environment.start()
        statusItemController.install()

        // Re-arm the daily recap on every launch: the scheduled body carries the day's numbers,
        // so it needs refreshing rather than surviving from a previous run.
        let settings = environment.activityCenter.settings
        let isDevelopmentBuild =
            Bundle.main.bundleIdentifier == "com.pawprint.app.rpgdev"
            || Bundle.main.object(forInfoDictionaryKey: "PawprintDevelopmentBuild") as? Bool == true
        let permissionRepairRequested =
            ProcessInfo.processInfo.arguments.contains("--permission-repair")
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
        if permissionRepairRequested {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PermissionRepairWindowController.shared.present()
            }
        } else if !settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingWindowController.shared.present()
            }
        } else if isDevelopmentBuild, !PermissionsManager.shared.allGranted {
            // A local development app can lose its TCC grants while its production counterpart
            // remains healthy. Bring the repair controls forward instead of hiding the failure.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PermissionRepairWindowController.shared.present()
            }
        }

        // A development bundle must never replace itself with an upstream release.
        if !isDevelopmentBuild {
            UpdateChecker.shared.startPeriodicChecks(settings: settings)
        }

        // Screenshot capture, GIF rendering, demo seeding and the probe suite. Compiled out
        // of a release build entirely — see `DebugCommand`.
        #if DEBUG
        DebugCommand.runIfRequested(self, adventureSnapshot: adventureSnapshot)
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        AdventureExpeditionCenter.shared.stopUpdates()
        AdventureExpeditionHUDController.shared.hide()
        statusItemController.remove()
        MenuBarIconAnimator.shared.stop()
        TrackingCoordinator.shared.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard Bundle.main.bundleIdentifier == "com.pawprint.app.rpgdev",
              environment.activityCenter.settings.hasCompletedOnboarding,
              !PermissionsManager.shared.allGranted else { return }
        PermissionRepairWindowController.shared.present()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applyDockIconPolicy() {
        NSApp.setActivationPolicy(
            environment.activityCenter.settings.showDockIcon ? .regular : .accessory
        )
    }
}
