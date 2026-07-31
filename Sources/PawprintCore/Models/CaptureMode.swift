import Foundation

/// Whether this process is a screenshot run.
///
/// Several places behave differently while the README screenshots are being taken: the popover
/// stops animating (an animated close finishes a runloop turn late and lost every other shot), the
/// announcement feed stops refreshing (a live notice would float over whichever tab was being
/// photographed), and recording is suspended (a capture run should not write its own events into
/// the history it is photographing).
///
/// All of it is development behaviour, so in a release build this is a compile-time `false` and
/// the branches fold away. The environment is not read at all.
package enum CaptureMode {
    #if DEBUG
    package static let isActive = ProcessInfo.processInfo.environment["PAWPRINT_SHOTS"] != nil
    #else
    package static let isActive = false
    #endif
}
