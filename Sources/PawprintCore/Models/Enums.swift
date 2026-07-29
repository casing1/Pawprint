import Foundation

package enum ShortcutType: String, Codable, CaseIterable {
    case copy, paste, cut, undo, redo, selectAll, screenshot, spotlight, appSwitch
}

package enum ClipboardAction: String, Codable, CaseIterable {
    case copy, paste, cut
}

package enum ClipboardDataType: String, Codable, CaseIterable {
    case text
    case richText
    case url
    case image
    case file
    case other

    package var displayName: String {
        switch self {
        case .text: return L10n.t("enums.6223fadb")
        case .richText: return L10n.t("enums.94a6475e")
        case .url: return "URL"
        case .image: return L10n.t("enums.981f89bf")
        case .file: return L10n.t("enums.68b8eecb")
        case .other: return L10n.t("enums.44650a96")
        }
    }
}

package enum MacStateEventType: String, Codable {
    case sleep, wake, screenLock, screenUnlock, chargerConnect, chargerDisconnect
}

/// The lighthearted "today's activity type" tag. Never presented as a scientific claim.
/// The lighthearted "today's activity type" tag. Never presented as a scientific claim.
///
/// Tags carry a `facet` so the picker can take at most one per facet — an earlier version was
/// almost entirely keyboard/pointer tags, so a day would come back labelled three different ways
/// of saying "you typed". Facets spread the description across how you worked, when, and on what.
package enum ActivityTag: String, Codable, CaseIterable {
    // Typing style
    case steadyTyper
    case burstTyper
    case editorType
    // Pointer style
    case mouseExplorer
    case scrollTraveler
    // Efficiency habits
    case shortcutExpert
    case pasteHeavy
    // Attention shape
    case focused
    case appHopper
    case chaotic
    // Rhythm of the day
    case earlyBird
    case nightOwl
    case marathoner
    case sprinter
    // Machine & environment
    case unplugged
    case multiScreen
    case dataHeavy
    case screenIdler

    /// Which aspect of the day a tag describes. At most one tag per facet is shown.
    package enum Facet: CaseIterable {
        case typing, pointer, efficiency, attention, rhythm, machine
    }

    package var facet: Facet {
        switch self {
        case .steadyTyper, .burstTyper, .editorType: return .typing
        case .mouseExplorer, .scrollTraveler: return .pointer
        case .shortcutExpert, .pasteHeavy: return .efficiency
        case .focused, .appHopper, .chaotic: return .attention
        case .earlyBird, .nightOwl, .marathoner, .sprinter: return .rhythm
        case .unplugged, .multiScreen, .dataHeavy, .screenIdler: return .machine
        }
    }

    package var label: String {
        switch self {
        case .steadyTyper: return L10n.t("enums.fbddde2a")
        case .burstTyper: return L10n.t("enums.6d65c6ee")
        case .editorType: return L10n.t("enums.f337674c")
        case .mouseExplorer: return L10n.t("enums.38e3c4ab")
        case .scrollTraveler: return L10n.t("enums.37a37788")
        case .shortcutExpert: return L10n.t("enums.3616de17")
        case .pasteHeavy: return L10n.t("enums.b260824b")
        case .focused: return L10n.t("enums.f722fdd4")
        case .appHopper: return L10n.t("enums.d930cb17")
        case .chaotic: return L10n.t("enums.0bdbc32c")
        case .earlyBird: return L10n.t("enums.64b28a94")
        case .nightOwl: return L10n.t("enums.be1d226d")
        case .marathoner: return L10n.t("enums.2087f474")
        case .sprinter: return L10n.t("enums.c78b8de8")
        case .unplugged: return L10n.t("enums.544ab871")
        case .multiScreen: return L10n.t("enums.eac94e53")
        case .dataHeavy: return L10n.t("enums.d80a27b5")
        case .screenIdler: return L10n.t("enums.cd06e4e1")
        }
    }

    package var emoji: String {
        switch self {
        case .steadyTyper: return "⌨️"
        case .burstTyper: return "💨"
        case .editorType: return "✏️"
        case .mouseExplorer: return "🖱️"
        case .scrollTraveler: return "📜"
        case .shortcutExpert: return "⚡️"
        case .pasteHeavy: return "📋"
        case .focused: return "🎯"
        case .appHopper: return "🐇"
        case .chaotic: return "🌀"
        case .earlyBird: return "🌅"
        case .nightOwl: return "🌙"
        case .marathoner: return "🏃"
        case .sprinter: return "⏱️"
        case .unplugged: return "🔋"
        case .multiScreen: return "🖥️"
        case .dataHeavy: return "🌐"
        case .screenIdler: return "💤"
        }
    }
}
