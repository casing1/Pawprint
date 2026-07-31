import Foundation

/// Clicks, cursor travel and scrolling.
///
/// The two figures that depend on the panel in front of you live here — metres of cursor travel and
/// screen-heights of scrolling — which is why this is the calculator that takes a `MachineFacts`.
/// It used to reach for `DisplayCalibration.current` mid-expression, so the same day produced
/// different numbers depending on which display happened to be attached when it was asked.
package enum PointerStats {

    package static func apply(_ raw: DailyRawCounters,
                              to s: inout DailySummary,
                              machine: MachineFacts) {
        s.leftClicks = raw.leftClicks
        s.rightClicks = raw.rightClicks
        s.doubleClicks = raw.doubleClicks
        s.dragCount = raw.dragCount
        s.totalClicks = raw.leftClicks + raw.rightClicks + raw.doubleClicks
        s.maxClicksPerMinute = raw.clicksPerMinute.max() ?? 0
        s.cursorDistanceMeters = machine.display.metres(fromPoints: raw.cursorDistancePixels)
        s.maxCursorSpeedPxPerSec = raw.maxCursorSpeedPxPerSec
        s.totalScrollPoints = raw.scrollUpPoints + raw.scrollDownPoints + raw.scrollHorizontalPoints
        s.scrollScreens = machine.display.screens(fromScrollPoints: s.totalScrollPoints)
        s.scrollUpPoints = raw.scrollUpPoints
        s.scrollDownPoints = raw.scrollDownPoints
        s.scrollDirectionChanges = raw.scrollDirectionChanges
        s.dragDistanceMeters = machine.display.metres(fromPoints: raw.dragDistancePoints)

        if s.totalClicks > 0 {
            s.doubleClickRatio = Double(raw.doubleClicks) / Double(s.totalClicks)
            s.scrollToClickRatio = s.scrollScreens / Double(s.totalClicks)
        }
    }
}

/// Copies, pastes and cuts. Counts and kinds only — never what was on the clipboard.
package enum ClipboardStats {

    package static func apply(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.clipboardCopyCount = raw.clipboardCopyCount
        s.clipboardPasteCount = raw.clipboardPasteCount
        s.clipboardCutCount = raw.clipboardCutCount
        s.clipboardTypeCounts = Dictionary(uniqueKeysWithValues: raw.clipboardTypeCounts.compactMap { key, value in
            ClipboardDataType(rawValue: key).map { ($0, value) }
        })
    }
}
