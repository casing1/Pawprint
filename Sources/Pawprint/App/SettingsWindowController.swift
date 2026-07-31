import AppKit
import SwiftUI
import PawprintCore

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
        // Restore the menu-bar-only policy unless the user actually wants a Dock icon.
        let wantsDockIcon = ActivityCenter.shared.settings.showDockIcon
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(wantsDockIcon ? .regular : .accessory)
        }
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
