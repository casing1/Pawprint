import AppKit

/// Observes global key-down and modifier-flag events system-wide to classify keystrokes by
/// category and detect well-known shortcut chords. It only ever reads `event.keyCode` and
/// `event.modifierFlags` — never `event.characters` — so no typed text is observable, let
/// alone stored.
final class KeyboardMonitor {
    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastCapsLockState = false

    func start() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
        }
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
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
