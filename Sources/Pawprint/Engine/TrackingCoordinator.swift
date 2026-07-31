import Foundation

/// Owns every tracking service and starts and stops them together.
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
    static let shared = TrackingCoordinator.live()

    /// Everything with a lifetime, in the order it is started.
    private let monitors: [any Monitor]
    /// The keyboard specifically, because the health check asks it a question no other monitor can
    /// answer. `nil` when a caller supplied monitors without one.
    private let keyboard: KeyboardMonitor?
    /// Re-registered on a permission change alongside the keyboard, for the same reason.
    private let mouse: (any Monitor)?
    private let permissions: PermissionsManager

    private var started = false
    private var healthTimer: Timer?
    /// One automatic re-registration per launch. If re-registering doesn't fix it, doing it every
    /// minute forever won't either, and the user needs to be told rather than quietly retried at.
    private var didAttemptKeyboardRecovery = false

    /// The composition the application runs.
    ///
    /// It used to construct these six inline, which meant the only way to ask "does stopping
    /// actually stop everything" was to run the app and watch. They are now handed in, so a test
    /// can pass six counters instead.
    static func live() -> TrackingCoordinator {
        let keyboard = KeyboardMonitor()
        let mouse = MouseMonitor()
        return TrackingCoordinator(
            monitors: [keyboard, mouse, ClipboardMonitor(), AppUsageMonitor(),
                       PowerAndSleepMonitor(), NetworkMonitor()],
            keyboard: keyboard,
            mouse: mouse)
    }

    init(monitors: [any Monitor],
         keyboard: KeyboardMonitor? = nil,
         mouse: (any Monitor)? = nil,
         permissions: PermissionsManager = .shared) {
        self.monitors = monitors
        self.keyboard = keyboard
        self.mouse = mouse
        self.permissions = permissions
    }

    /// Whether tracking is running. Each monitor also knows for itself; this is the coordinator's
    /// own answer, which is what `start` and `stop` are idempotent against.
    var isRunning: Bool { started }

    /// Starts the monitors. The centre they feed is started by `AppEnvironment` before this runs —
    /// a coordinator of trackers deciding the lifetime of the thing it reports to was the sort of
    /// implicit ordering a composition root exists to make explicit.
    func start() {
        guard !started else { return }
        started = true
        monitors.forEach { $0.start() }

        permissions.onChange = { [weak self] _, _ in
            // A grant that lands after launch leaves the existing registrations dead.
            self?.keyboard?.restart()
            self?.mouse?.restart()
            self?.didAttemptKeyboardRecovery = false
            self?.permissions.setKeyboardEventsStalled(false)
        }
        permissions.startPolling()

        healthTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkKeyboardHealth() }
        }
    }

    /// Modifier events arriving with no key events means the `.keyDown` registration is dead.
    /// Re-register once; if it is still dead a minute later, stop guessing and raise the flag.
    private func checkKeyboardHealth() {
        guard started, let keyboard, ActivityCenter.shared.settings.collectKeyboard else { return }
        guard keyboard.looksStalled else {
            permissions.setKeyboardEventsStalled(false)
            return
        }
        if didAttemptKeyboardRecovery {
            permissions.setKeyboardEventsStalled(true)
        } else {
            didAttemptKeyboardRecovery = true
            keyboard.restart()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        monitors.forEach { $0.stop() }
        healthTimer?.invalidate()
        healthTimer = nil
        permissions.onChange = nil
        permissions.stopPolling()
        ActivityCenter.shared.stop()
    }
}
