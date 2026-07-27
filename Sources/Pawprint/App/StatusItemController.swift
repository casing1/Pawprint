import AppKit
import SwiftUI

/// Owns the menu bar item and its popover.
///
/// This replaces SwiftUI's `MenuBarExtra`. That API renders its label once and did not redraw
/// when observable state changed, so the animated paw sat frozen; an `NSStatusItem` lets the
/// animation push each frame straight into the button's image, which is how menu bar animations
/// (RunCat and friends) are normally done.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var paceTimer: Timer?
    private var titleTick = 0

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = PawAnimator.shared.currentImage
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityLabel("Pawprint")
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        // Content is built on first open and torn down on close. Keeping a live
        // `NSHostingController` around would leave the whole SwiftUI tree — and its refresh
        // timers and observations — running while the popover is closed.

        // Push every animation frame straight into the button.
        PawAnimator.shared.onFrame = { [weak self] image in
            self?.statusItem?.button?.image = image
        }

        // The text beside the icon (WPM, key count…) changes far more slowly than the animation,
        // so it gets its own lazy refresh rather than riding the frame timer.
        refreshTitle()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPace()
                self?.titleTick += 1
                // The text beside the icon changes slowly; refresh it every few pace checks.
                if (self?.titleTick ?? 0) % 4 == 0 { self?.refreshTitle() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        paceTimer = timer
    }

    func remove() {
        paceTimer?.invalidate()
        paceTimer = nil
        PawAnimator.shared.onFrame = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func refreshPace() {
        let center = ActivityCenter.shared
        let idleFor = center.todaySummary.lastActivity.map { Date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        PawAnimator.shared.updatePace(
            liveWPM: center.liveWPM,
            isRecording: center.isRecordingActive,
            secondsSinceActivity: idleFor
        )
    }

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let text = Self.menuBarText()
        button.title = text.map { " \($0)" } ?? ""
    }

    private static func menuBarText() -> String? {
        let center = ActivityCenter.shared
        let summary = center.todaySummary
        switch center.settings.menuBarMetric {
        case .iconOnly:
            return nil
        case .wpm:
            return summary.maxWPM > 0 ? String(format: "%.0f WPM", summary.maxWPM) : nil
        case .totalKeys:
            return summary.totalKeyPresses > 0 ? Formatters.groupedNumber(summary.totalKeyPresses) : nil
        case .focusTime:
            return summary.longestFocusSeconds > 0 ? "Focus \(Formatters.compactDuration(summary.longestFocusSeconds))" : nil
        case .activeTime:
            return summary.activeSeconds > 0 ? "Active \(Formatters.compactDuration(summary.activeSeconds))" : nil
        case .undoCount:
            let undo = summary.shortcutCounts[.undo] ?? 0
            return undo > 0 ? "Undo \(undo)" : nil
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Rebuild each time so the popover always opens on fresh stats.
            popover.contentViewController = NSHostingController(rootView: PopoverRootView())

            // Pawprint runs as an accessory app (no Dock icon), so it is never the active
            // application on its own. Without activating first, the popover's window never
            // becomes key and every control inside it silently ignores clicks — pickers won't
            // open, buttons don't fire. Activate, then show, then take key explicitly.
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }

    /// Releases the SwiftUI content so its timers stop while the popover isn't visible.
    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}

