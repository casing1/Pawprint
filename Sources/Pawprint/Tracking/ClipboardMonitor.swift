import AppKit

/// Tiny cross-tracker hint so `ClipboardMonitor` can tell a cut from a copy, and can snapshot
/// the clipboard's *type* at the moment of a paste (pasting normally doesn't change
/// `NSPasteboard.changeCount`, so there's nothing else to poll for it). Both trackers only
/// ever touch this on the main thread, so no locking is needed.
final class ClipboardShortcutHints {
    static let shared = ClipboardShortcutHints()
    var lastCutAt: Date?
    var lastPasteAt: Date?
    private init() {}
}

/// Polls `NSPasteboard.general.changeCount` to notice copy/cut events (there is no push API
/// for pasteboard changes). Only `pasteboard.types` is ever inspected to classify the kind of
/// content — the actual string/data payload is never read, matching the "유형만 분류, 내용은
/// 저장하지 않는다" rule in the spec.
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastObservedPasteAt: Date?

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let now = Date()

        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            let type = Self.classify(pasteboard.types ?? [])
            let action: ClipboardAction
            if let cutAt = ClipboardShortcutHints.shared.lastCutAt, now.timeIntervalSince(cutAt) < 1.2 {
                action = .cut
            } else {
                action = .copy
            }
            ActivityCenter.shared.recordClipboard(action: action, type: type, at: now)
        }

        if let pasteAt = ClipboardShortcutHints.shared.lastPasteAt, pasteAt != lastObservedPasteAt {
            lastObservedPasteAt = pasteAt
            let type = Self.classify(pasteboard.types ?? [])
            ActivityCenter.shared.recordClipboard(action: .paste, type: type, at: pasteAt)
        }
    }

    private static func classify(_ types: [NSPasteboard.PasteboardType]) -> ClipboardDataType {
        if types.contains(.fileURL) { return .file }
        if types.contains(.URL) { return .url }
        if types.contains(.tiff) || types.contains(.png) || types.contains(.pdf) { return .image }
        if types.contains(.rtf) || types.contains(.rtfd) || types.contains(.html) { return .richText }
        if types.contains(.string) { return .text }
        return .other
    }
}
