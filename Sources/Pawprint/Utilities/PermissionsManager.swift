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

    private var pollTimer: Timer?

    private init() {}

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Starts polling permission state (system APIs offer no change notification for these).
    /// `AXIsProcessTrusted`/`IOHIDCheckAccess` are cross-process calls, so polling stops as soon
    /// as both are granted — the common steady state — instead of running for the whole session.
    func startPolling(interval: TimeInterval = 2.0) {
        pollTimer?.invalidate()
        guard !allGranted else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refresh()
            if self.allGranted { self.stopPolling() }
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
