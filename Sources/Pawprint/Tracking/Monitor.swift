import Foundation

/// Something that watches the machine and reports to `ActivityCenter`.
///
/// The six of them had nothing in common but a convention — `start()` and `stop()`, named the same
/// way and behaving slightly differently. Two were not idempotent: calling `start()` twice on the
/// app-usage monitor added a second `NSWorkspace` observer, so every application switch would have
/// been counted twice, and the power monitor did the same with its four. Nothing hit that today,
/// because `TrackingCoordinator` guards on a flag — but the guard was the only thing standing
/// between a double-start and a day whose numbers were quietly doubled, and a guard in the caller
/// is the wrong place for an invariant of the callee.
///
/// The contract is now stated rather than assumed: `start()` on a running monitor does nothing,
/// `stop()` on a stopped one does nothing, and `isRunning` says which it is.
@MainActor
protocol Monitor: AnyObject {
    /// Begins observing. Does nothing if already running.
    func start()
    /// Stops observing and releases every registration. Does nothing if already stopped.
    func stop()
    /// Whether this monitor is currently observing.
    var isRunning: Bool { get }
}

extension Monitor {
    /// Tears the monitor down and registers it again.
    ///
    /// The only way to pick up a permission that was granted after the original registration: a
    /// global `.keyDown` monitor registered before Input Monitoring stays dead once it is granted.
    func restart() {
        stop()
        start()
    }
}
