import AppKit
import SwiftUI
import PawprintCore

/// Owns the interactive adventure window.
///
/// The compact HUD owns the complete play loop. This resizable companion remains available for
/// people who want the larger combat log, reward breakdown, and gallery context.
@MainActor
final class AdventureWindowController: NSObject, NSWindowDelegate {
    static let shared = AdventureWindowController()

    private var window: NSWindow?
    var adventureWindow: NSWindow? { window }

    func show() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Recreate the root for every newly opened session. This refreshes the retained history
        // and deliberately discards battles from a window that was previously closed.
        let hosting = NSHostingController(rootView: AdventureRootView())

        if let window {
            window.contentViewController = hosting
            window.title = L10n.t("adventure.window.title")
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t("adventure.window.title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 780, height: 560)
        window.setContentSize(NSSize(width: 920, height: 640))
        window.delegate = self
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        Self.releaseContent(from: notification)
        AppWindowActivationPolicy.restore(afterClosing: notification)
    }

    /// The controller intentionally retains its NSWindow for cheap reopening, but not the SwiftUI
    /// session inside it. Releasing the host here drops derived history, selection and battle logs
    /// as soon as the user closes the window.
    static func releaseContent(from notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        closingWindow.contentViewController = nil
    }

    func refreshLocalizedTitle() {
        window?.title = L10n.t("adventure.window.title")
    }
}

enum AdventureOpener {
    static func open() {
        MainActor.assumeIsolated {
            AdventureWindowController.shared.show()
        }
    }
}
