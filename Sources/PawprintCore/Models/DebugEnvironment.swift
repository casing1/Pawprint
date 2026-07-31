import Foundation

/// The development-only environment knobs, in one place.
///
/// Screenshot capture needs to force things the app would never do on its own — a specific gallery
/// sort, a taller scroll view, a light position for the foil, a settings tab. Each used to read the
/// environment where it was used, which left the branches live in a shipped build and the variable
/// names in the binary.
///
/// Named accessors rather than a string-keyed lookup, deliberately: a lookup keeps the name at the
/// call site as a literal, and a literal survives into the binary whatever the function does. With
/// the names on this side of the `#if`, a release build has neither the strings nor the branches.
package enum DebugEnvironment {
    #if DEBUG
    private static func value(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// Gallery sort for a capture run. The app always opens on rarity.
    package static var gallerySort: String? { value("PAWPRINT_SHOT_SORT") }
    /// Popover scroll height, so a whole tab fits in one screenshot.
    package static var popoverHeight: String? { value("PAWPRINT_SHOT_HEIGHT") }
    /// Where the light is for the foil, since a captured window contains no pointer.
    package static var foilPointer: String? { overriddenFoilPointer ?? value("PAWPRINT_FOIL_POINTER") }

    /// Set frame by frame while rendering the foil animation, which has to move the light itself.
    nonisolated(unsafe) private static var overriddenFoilPointer: String?

    package static func setFoilPointer(_ point: String?) { overriddenFoilPointer = point }
    /// Which settings tab to open.
    package static var settingsTab: String? { value("PAWPRINT_SETTINGS_TAB") }
    /// Frame-by-frame logging while tuning the menu bar animation.
    package static var logsPawFrames: Bool { value("PAWPRINT_DEBUG_PAW") != nil }
    /// Opens the day's cat card with every trait note showing, which is otherwise behind a click.
    package static var expandsCatNotes: Bool { value("PAWPRINT_CAT_NOTES") != nil }
    #else
    package static var gallerySort: String? { nil }
    package static var popoverHeight: String? { nil }
    package static var foilPointer: String? { nil }
    package static func setFoilPointer(_ point: String?) {}
    package static var settingsTab: String? { nil }
    package static var logsPawFrames: Bool { false }
    package static var expandsCatNotes: Bool { false }
    #endif
}
