import AppKit
import PawprintCore

/// Observes global key-down and modifier-flag events system-wide to classify keystrokes by
/// category and detect well-known shortcut chords. It only ever reads `event.keyCode` and
/// `event.modifierFlags` — never `event.characters` — so no typed text is observable, let
/// alone stored.
@MainActor
final class KeyboardMonitor: Monitor {
    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastCapsLockState = false

    /// Events seen since the monitors were last registered.
    ///
    /// These exist to catch a failure the permission APIs cannot report. `.keyDown` and
    /// `.flagsChanged` are gated differently by TCC: a global `.keyDown` monitor needs Input
    /// Monitoring, while `.flagsChanged` is delivered with Accessibility alone. A monitor
    /// registered before Input Monitoring was granted stays dead afterwards — granting the
    /// permission does not revive an existing registration — so the app kept counting modifier
    /// keys and silently counted no letters at all. `IOHIDCheckAccess` reports "granted" the whole
    /// time, because by then it is.
    ///
    /// Comparing the two counters detects exactly that state: modifiers arriving, characters not.
    private(set) var keyDownsSeen = 0
    private(set) var flagsSeen = 0

    /// True when modifier events are arriving but key events are not — the signature of a dead
    /// `.keyDown` registration. Needs a few modifier events before it will claim anything, so a
    /// genuinely idle keyboard is never mistaken for a broken one.
    var looksStalled: Bool { flagsSeen >= 3 && keyDownsSeen == 0 }

    var isRunning: Bool { keyDownMonitor != nil }

    func start() {
        guard keyDownMonitor == nil else { return }
        keyDownsSeen = 0
        flagsSeen = 0
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.keyDownsSeen += 1
            self?.handleKeyDown(event)
        }
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.flagsSeen += 1
            self?.handleFlagsChanged(event)
        }
    }

    func stop() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = flagsChangedMonitor { NSEvent.removeMonitor(m); flagsChangedMonitor = nil }
    }

    private func handleKeyDown(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        let date = Date()
        let category = KeyCodeMap.category(for: keyCode)
        let hasCmd = modifiers.contains(.command)
        let hasShift = modifiers.contains(.shift)

        DispatchQueue.main.async {
            ActivityCenter.shared.recordKeyPress(category: category, keyCode: keyCode, at: date)

            guard hasCmd else { return }
            switch keyCode {
            case KeyCodeMap.ANSI.c: ActivityCenter.shared.recordShortcut(.copy, at: date)
            case KeyCodeMap.ANSI.v:
                ActivityCenter.shared.recordShortcut(.paste, at: date)
                ClipboardShortcutHints.shared.lastPasteAt = date
            case KeyCodeMap.ANSI.x:
                ActivityCenter.shared.recordShortcut(.cut, at: date)
                ClipboardShortcutHints.shared.lastCutAt = date
            case KeyCodeMap.ANSI.a: ActivityCenter.shared.recordShortcut(.selectAll, at: date)
            case KeyCodeMap.ANSI.z:
                ActivityCenter.shared.recordShortcut(hasShift ? .redo : .undo, at: date)
            case KeyCodeMap.ANSI.y where hasShift == false:
                ActivityCenter.shared.recordShortcut(.redo, at: date)
            case KeyCodeMap.ANSI.three where hasShift,
                 KeyCodeMap.ANSI.four where hasShift,
                 KeyCodeMap.ANSI.five where hasShift:
                ActivityCenter.shared.recordShortcut(.screenshot, at: date)
            case KeyCodeMap.spaceKeyCode:
                ActivityCenter.shared.recordShortcut(.spotlight, at: date)
            case KeyCodeMap.tabKeyCode:
                ActivityCenter.shared.recordShortcut(.appSwitch, at: date)
            default:
                break
            }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let keyCode = event.keyCode
        let date = Date()
        let category = KeyCodeMap.category(for: keyCode)

        // CapsLock reports state via the flag itself rather than distinct down/up events.
        if keyCode == 0x39 {
            let isOn = event.modifierFlags.contains(.capsLock)
            guard isOn != lastCapsLockState else { return }
            lastCapsLockState = isOn
            guard isOn else { return }
        }

        DispatchQueue.main.async {
            ActivityCenter.shared.recordKeyPress(category: category, keyCode: keyCode, at: date)
        }
    }
}
