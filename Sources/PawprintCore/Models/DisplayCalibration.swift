import Foundation

/// Physical calibration of the display, as far as the statistics are concerned.
///
/// "Your cursor travelled 123 m" and "you scrolled 863 screen-heights" are the only two figures
/// that depend on the panel in front of you, and the panel is an `NSScreen` — AppKit, which the
/// domain does not import. So the domain states what it needs and the application supplies it.
///
/// This is a seam, not the destination. `StatsEngine` still reaches for
/// `DisplayCalibration.current` mid-calculation, which is the thing that stops its output being a
/// pure function of its input; §S6 turns it into a parameter. Moving it behind a protocol first is
/// what makes that change mechanical rather than exploratory.
package protocol DisplayCalibrating {
    /// Points of cursor delta per physical metre of desk-surface movement.
    var pointsPerMetre: Double { get }
    /// Height of the main display in points — one "screen" of scrolling.
    var screenHeightPoints: Double { get }
    /// Physical height of the main display in metres.
    var screenHeightMetres: Double { get }
}

extension DisplayCalibrating {
    package func metres(fromPoints points: Double) -> Double { points / pointsPerMetre }
    package func screens(fromScrollPoints points: Double) -> Double { points / screenHeightPoints }
}

/// What the statistics use when nothing better has been supplied.
///
/// The numbers are the same fallbacks the AppKit implementation uses for a display that does not
/// report a physical size, so an uninjected calculation produces the figures the app has always
/// produced on such a display rather than zeroes or a crash.
package struct FallbackDisplayCalibration: DisplayCalibrating {
    package init() {}
    package var pointsPerMetre: Double { 5200 }
    package var screenHeightPoints: Double { 900 }
    package var screenHeightMetres: Double { 0.2 }
}

package enum DisplayCalibration {
    // Not `Sendable`: the AppKit implementation recomputes itself when the screen configuration
    // changes, so its stored values are mutable and promising otherwise would be a lie the
    // compiler correctly refused. `current` is written once during launch, before anything reads
    // it, which is what makes the unchecked access below safe rather than the protocol.
    /// Replaced once at launch with the real display. Tests and any headless use get the fallback,
    /// which is why the two conversions above are the only summary fields the characterization
    /// tests decline to pin to an exact value.
    nonisolated(unsafe) package static var current: any DisplayCalibrating = FallbackDisplayCalibration()
}
