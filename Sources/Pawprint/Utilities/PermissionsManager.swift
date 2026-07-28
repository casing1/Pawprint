import AppKit
import ApplicationServices
import IOKit.hid
import Observation

/// Tracks the two OS permissions Pawprint needs to observe global keyboard/mouse events.
/// Keyboard events (keyDown/flagsChanged) require Input Monitoring; mouse events and some
/// app-focus APIs require Accessibility. Neither permission lets Pawprint read what was typed —
/// it only lets the process see that *an* event happened, which is all `KeyCodeMap` classifies.
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    private(set) var accessibilityGranted: Bool = AXIsProcessTrusted()
    private(set) var inputMonitoringGranted: Bool = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

    var allGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    /// Set by `TrackingCoordinator` when modifier events are arriving but key events are not.
    ///
    /// Lives here, on the observable object the permission UI already watches, rather than on the
    /// coordinator — which is a plain class, so a flag there would change without redrawing
    /// anything and the warning would only appear if you happened to reopen the window.
    ///
    /// It is not a permission in TCC's sense: `IOHIDCheckAccess` reports granted throughout. It is
    /// the state where the grant exists but this process's `.keyDown` registration predates it.
    private(set) var keyboardEventsStalled = false

    func setKeyboardEventsStalled(_ stalled: Bool) {
        guard stalled != keyboardEventsStalled else { return }
        keyboardEventsStalled = stalled
    }

    private var pollTimer: Timer?

    /// Called whenever a permission flips, in either direction. Event monitors registered while a
    /// permission was missing stay dead after it is granted, so somebody has to re-register them.
    var onChange: ((_ accessibility: Bool, _ inputMonitoring: Bool) -> Void)?

    private init() {}

    @discardableResult
    func refresh() -> Bool {
        let ax = AXIsProcessTrusted()
        let hid = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        let changed = ax != accessibilityGranted || hid != inputMonitoringGranted
        accessibilityGranted = ax
        inputMonitoringGranted = hid
        if changed { onChange?(ax, hid) }
        return changed
    }

    /// Polls permission state; the system offers no change notification for either of these.
    ///
    /// Polling used to stop for good once both were granted. That saved two cross-process calls
    /// and cost the app its only chance to notice a permission being revoked later — after which
    /// it would keep running with dead monitors and no idea. It now drops to a slow cadence
    /// instead of stopping, which is cheap enough to leave on for the session.
    func startPolling(interval: TimeInterval = 2.0) {
        pollTimer?.invalidate()
        schedule(every: allGranted ? Self.settledInterval : interval, fast: !allGranted)
    }

    /// Once everything is granted there is nothing to wait for, only revocation to notice.
    private static let settledInterval: TimeInterval = 30

    private func schedule(every interval: TimeInterval, fast: Bool) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refresh()
            // Swap cadence when the situation changes, so waiting for a grant stays responsive
            // and the settled state stays quiet.
            if fast && self.allGranted {
                self.pollTimer?.invalidate()
                self.schedule(every: Self.settledInterval, fast: false)
            } else if !fast && !self.allGranted {
                self.pollTimer?.invalidate()
                self.schedule(every: 2.0, fast: true)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Shows the system Accessibility prompt (first time only) and marks the app for the
    /// "Privacy & Security > Accessibility" list so the user can grant it there afterward.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    /// Requests Input Monitoring access. macOS shows its own system prompt the first time;
    /// on later calls (already denied) it silently returns false and the user must flip it
    /// on manually in System Settings, which `openInputMonitoringSettings()` deep-links to.
    func requestInputMonitoring() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        refresh()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
