import XCTest
import PawprintCore
@testable import Pawprint

/// That starting and stopping tracking does what it says.
///
/// `TrackingCoordinator` constructed its six monitors inline, so the only way to ask "does stopping
/// actually stop everything" was to run the app and watch. Two of those monitors were not
/// idempotent either: a second `start()` on the app-usage monitor added a second `NSWorkspace`
/// observer, and every application switch would have been counted twice. Nothing hit that, because
/// the coordinator guards on a flag — but a guard in the caller is the wrong place for an invariant
/// of the callee, and it is exactly the kind of thing that survives a refactor and then doesn't.
@MainActor
final class MonitorLifecycleTests: XCTestCase {

    /// A monitor that only counts. Enough to state the contract: the real ones register with
    /// AppKit and IOKit, which a test process has no business doing.
    private final class CountingMonitor: Monitor {
        private(set) var starts = 0
        private(set) var stops = 0
        private(set) var isRunning = false

        func start() {
            guard !isRunning else { return }
            isRunning = true
            starts += 1
        }

        func stop() {
            guard isRunning else { return }
            isRunning = false
            stops += 1
        }
    }

    private func coordinator(_ monitors: [CountingMonitor]) -> TrackingCoordinator {
        TrackingCoordinator(monitors: monitors)
    }

    func testStartingRunsEveryMonitorExactlyOnce() {
        let monitors = (0..<6).map { _ in CountingMonitor() }
        let coordinator = coordinator(monitors)

        coordinator.start()
        XCTAssertTrue(coordinator.isRunning)
        XCTAssertEqual(monitors.map(\.starts), Array(repeating: 1, count: 6))
        XCTAssertTrue(monitors.allSatisfy(\.isRunning))
        coordinator.stop()
    }

    func testStoppingStopsEveryMonitor() {
        let monitors = (0..<6).map { _ in CountingMonitor() }
        let coordinator = coordinator(monitors)

        coordinator.start()
        coordinator.stop()
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(monitors.map(\.stops), Array(repeating: 1, count: 6))
        XCTAssertFalse(monitors.contains(where: \.isRunning), "a monitor was left running")
    }

    /// The point of the protocol. A second start must be a no-op, not a second registration.
    func testStartingTwiceRegistersOnce() {
        let monitors = (0..<3).map { _ in CountingMonitor() }
        let coordinator = coordinator(monitors)

        coordinator.start()
        coordinator.start()
        coordinator.start()
        XCTAssertEqual(monitors.map(\.starts), [1, 1, 1])
        coordinator.stop()
    }

    func testStoppingTwiceIsHarmless() {
        let monitors = [CountingMonitor()]
        let coordinator = coordinator(monitors)

        coordinator.start()
        coordinator.stop()
        coordinator.stop()
        XCTAssertEqual(monitors[0].stops, 1)
        XCTAssertFalse(coordinator.isRunning)
    }

    func testStoppingBeforeStartingDoesNothing() {
        let monitors = [CountingMonitor()]
        let coordinator = coordinator(monitors)

        coordinator.stop()
        XCTAssertEqual(monitors[0].starts, 0)
        XCTAssertEqual(monitors[0].stops, 0)
    }

    /// Tracking can be paused and resumed from the menu bar, so the cycle has to be repeatable.
    func testTheCycleCanRepeat() {
        let monitors = [CountingMonitor()]
        let coordinator = coordinator(monitors)

        for _ in 0..<5 {
            coordinator.start()
            coordinator.stop()
        }
        XCTAssertEqual(monitors[0].starts, 5)
        XCTAssertEqual(monitors[0].stops, 5)
    }

    /// `restart` is how a permission granted after launch is picked up — a `.keyDown` monitor
    /// registered before Input Monitoring stays dead until it is registered again.
    func testRestartingIsAStopFollowedByAStart() {
        let monitor = CountingMonitor()
        monitor.start()
        monitor.restart()

        XCTAssertEqual(monitor.starts, 2)
        XCTAssertEqual(monitor.stops, 1)
        XCTAssertTrue(monitor.isRunning)
    }

    /// Restarting something that was never started still leaves it running, which is what the
    /// permission-change handler needs: it does not know or care what the state was.
    func testRestartingSomethingStoppedStartsIt() {
        let monitor = CountingMonitor()
        monitor.restart()
        XCTAssertTrue(monitor.isRunning)
        XCTAssertEqual(monitor.starts, 1)
        XCTAssertEqual(monitor.stops, 0)
    }

    /// Every real monitor reports itself stopped before it is started. Constructing them is safe —
    /// none registers anything in its initializer — and this is what would catch one that did.
    func testTheRealMonitorsStartStopped() {
        let monitors: [any Monitor] = [
            KeyboardMonitor(), MouseMonitor(), ClipboardMonitor(),
            AppUsageMonitor(), PowerAndSleepMonitor(), NetworkMonitor(),
        ]
        for monitor in monitors {
            XCTAssertFalse(monitor.isRunning, "\(type(of: monitor)) registered in its initializer")
        }
    }
}
