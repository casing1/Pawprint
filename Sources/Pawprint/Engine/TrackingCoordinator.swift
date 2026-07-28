import Foundation

/// Owns every tracking service and starts/stops them together with `ActivityCenter`.
///
/// Keyboard and mouse tracking need OS permissions to receive anything. The monitors are still
/// started unconditionally, but the old assumption behind that — "macOS just delivers nothing
/// until permission is granted, and starts delivering afterwards" — is wrong for key events. A
/// global `.keyDown` monitor registered before Input Monitoring was granted **stays dead** once
/// it is; only re-registering revives it. `.flagsChanged` is gated by Accessibility instead, so
/// it kept working, and the visible result was a keyboard heatmap made entirely of modifier keys
/// with not one letter on it.
///
/// So permission changes now re-register the monitors, and `checkKeyboardHealth` catches the case
/// the permission APIs cannot see: Input Monitoring reads as granted, because by then it is, while
/// the registration made before the grant is still dead.
@MainActor
final class TrackingCoordinator {
    static let shared = TrackingCoordinator()

    private let keyboard = KeyboardMonitor()
    private let mouse = MouseMonitor()
    private let clipboard = ClipboardMonitor()
    private let appUsage = AppUsageMonitor()
    private let powerAndSleep = PowerAndSleepMonitor()
    private let network = NetworkMonitor()

    private var started = false
    private var healthTimer: Timer?
    /// One automatic re-registration per launch. If re-registering doesn't fix it, doing it every
    /// minute forever won't either, and the user needs to be told rather than quietly retried at.
    private var didAttemptKeyboardRecovery = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        ActivityCenter.shared.start()
        keyboard.start()
        mouse.start()
        clipboard.start()
        appUsage.start()
        powerAndSleep.start()
        network.start()

        PermissionsManager.shared.onChange = { [weak self] _, _ in
            // A grant that lands after launch leaves the existing registrations dead.
            self?.keyboard.restart()
            self?.mouse.restart()
            self?.didAttemptKeyboardRecovery = false
            PermissionsManager.shared.setKeyboardEventsStalled(false)
        }
        PermissionsManager.shared.startPolling()

        healthTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkKeyboardHealth() }
        }
    }

    /// Modifier events arriving with no key events means the `.keyDown` registration is dead.
    /// Re-register once; if it is still dead a minute later, stop guessing and raise the flag.
    private func checkKeyboardHealth() {
        guard started, ActivityCenter.shared.settings.collectKeyboard else { return }
        guard keyboard.looksStalled else {
            PermissionsManager.shared.setKeyboardEventsStalled(false)
            return
        }
        if didAttemptKeyboardRecovery {
            PermissionsManager.shared.setKeyboardEventsStalled(true)
        } else {
            didAttemptKeyboardRecovery = true
            keyboard.restart()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        keyboard.stop()
        mouse.stop()
        clipboard.stop()
        appUsage.stop()
        powerAndSleep.stop()
        network.stop()
        healthTimer?.invalidate()
        healthTimer = nil
        PermissionsManager.shared.onChange = nil
        PermissionsManager.shared.stopPolling()
        ActivityCenter.shared.stop()
    }
}
