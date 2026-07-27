import Foundation

/// Owns every tracking service and starts/stops them together with `ActivityCenter`.
/// Keyboard/mouse tracking additionally needs the OS permissions to actually receive events —
/// they're started unconditionally (macOS just delivers nothing until permission is granted),
/// and `PermissionsManager` polling means the popover can prompt the user without a relaunch.
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
        PermissionsManager.shared.startPolling()
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
        PermissionsManager.shared.stopPolling()
        ActivityCenter.shared.stop()
    }
}
