import AppKit
import SwiftUI
import PawprintCore

/// Keeps the menu-bar-only activation policy from stranding another normal window.
///
/// Settings used to be the only auxiliary window, so closing it could always return the app to
/// `.accessory`. Adventure makes multiple windows possible: whichever one closes first must leave
/// the app regular while another titled window is still open.
@MainActor
enum AppWindowActivationPolicy {
    static func desiredPolicy(
        wantsDockIcon: Bool,
        hasVisibleTitledWindow: Bool
    ) -> NSApplication.ActivationPolicy {
        wantsDockIcon || hasVisibleTitledWindow ? .regular : .accessory
    }

    static func refresh(wantsDockIcon: Bool) {
        let hasVisibleTitledWindow = NSApp.windows.contains { window in
            (window.isVisible || window.isMiniaturized)
                && window.styleMask.contains(.titled)
        }
        NSApp.setActivationPolicy(
            desiredPolicy(
                wantsDockIcon: wantsDockIcon,
                hasVisibleTitledWindow: hasVisibleTitledWindow
            )
        )
    }

    static func restore(afterClosing notification: Notification) {
        let closingWindow = notification.object as? NSWindow
        DispatchQueue.main.async {
            let closingWindowReopened = closingWindow.map {
                $0.isVisible || $0.isMiniaturized
            } ?? false
            let hasAnotherWindow = closingWindowReopened || NSApp.windows.contains { window in
                window !== closingWindow
                    && (window.isVisible || window.isMiniaturized)
                    && window.styleMask.contains(.titled)
            }
            let wantsDockIcon = ActivityCenter.shared.settings.showDockIcon
            NSApp.setActivationPolicy(
                desiredPolicy(
                    wantsDockIcon: wantsDockIcon,
                    hasVisibleTitledWindow: hasAnotherWindow
                )
            )
        }
    }
}

/// Owns the Settings window.
///
/// SwiftUI's `Settings` scene is opened via `NSApp.showSettingsWindow:`, but that selector is not
/// installed on this app's `NSApplication` (verified at runtime: it responds to neither
/// `showSettingsWindow:` nor `showPreferencesWindow:`). Calling it threw an unrecognized-selector
/// exception, which left the app alive but wedged — after that, nothing in the popover responded.
/// Hosting the window ourselves removes the dependency on those selectors entirely.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        // An accessory app can't focus a normal window. Switch to a regular app for as long as
        // the window is open, then drop back so the Dock icon doesn't linger.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsRootView(startOn: DebugEnvironment.settingsTab)
                .pawprintEnvironment())
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t("settingsWindowController.4e8f752d")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppWindowActivationPolicy.restore(afterClosing: notification)
    }
}

/// Entry point used by the popover's gear button.
enum SettingsOpener {
    static func open() {
        MainActor.assumeIsolated {
            SettingsWindowController.shared.show()
        }
    }
}
