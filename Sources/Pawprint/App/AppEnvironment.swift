import AppKit
import PawprintCore

/// Where the application is assembled.
///
/// Pawprint had no such place. Every object reached for whatever it needed through a `.shared`,
/// which is why almost nothing below `AppDelegate` could be constructed in a test: asking
/// `ActivityCenter` a question meant it opening the real database in Application Support, and
/// asking a view a question meant standing up the whole application.
///
/// This is the single point where the real store, the real clock and the real display calibration
/// are chosen and handed over. Nothing here is clever — that is the point. If you want to know what
/// the running application is made of, it is this file.
///
/// **The `.shared` accessors have not gone.** 225 of them exist across the tree, and removing them
/// is S9's job, not this one's. What has changed is that they are no longer where construction
/// *happens*: `ActivityCenter` now takes its store and its clock, and `.shared` is one particular
/// composition rather than the only possible one.
@MainActor
final class AppEnvironment {

    /// The composition the application runs.
    static let live = AppEnvironment(
        store: PawprintStore.shared,
        clock: SystemClock(),
        calibration: DisplayMetrics.shared)

    let store: any ActivityStore
    let clock: any Clock
    let activityCenter: ActivityCenter

    init(store: any ActivityStore, clock: any Clock, calibration: any DisplayCalibrating) {
        // Before anything computes a summary. The domain states what it needs from the display and
        // AppKit is what can answer; leaving this to first use would have the first few figures
        // computed against the fallback panel.
        DisplayCalibration.current = calibration

        self.store = store
        self.clock = clock
        // `.shared` while the rest of the tree still reaches for it. The composition above is what
        // built it, so a different composition is a matter of construction rather than of surgery.
        self.activityCenter = ActivityCenter.shared
    }

    /// Starts everything with a lifetime.
    func start() {
        activityCenter.start()
        TrackingCoordinator.shared.start()
        MenuBarIconAnimator.shared.start()
    }

    func stop() {
        TrackingCoordinator.shared.stop()
        activityCenter.stop()
    }
}
