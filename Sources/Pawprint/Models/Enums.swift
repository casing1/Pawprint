import Foundation

enum ShortcutType: String, Codable, CaseIterable {
    case copy, paste, cut, undo, redo, selectAll, screenshot, spotlight, appSwitch
}

enum ClipboardAction: String, Codable, CaseIterable {
    case copy, paste, cut
}

enum ClipboardDataType: String, Codable, CaseIterable {
    case text
    case richText
    case url
    case image
    case file
    case other

    var displayName: String {
        switch self {
        case .text: return "텍스트"
        case .richText: return "서식 있는 텍스트"
        case .url: return "URL"
        case .image: return "이미지"
        case .file: return "파일"
        case .other: return "기타"
        }
    }
}

enum MacStateEventType: String, Codable {
    case sleep, wake, screenLock, screenUnlock, chargerConnect, chargerDisconnect
}

/// The lighthearted "today's activity type" tag. Never presented as a scientific claim.
/// The lighthearted "today's activity type" tag. Never presented as a scientific claim.
///
/// Tags carry a `facet` so the picker can take at most one per facet — an earlier version was
/// almost entirely keyboard/pointer tags, so a day would come back labelled three different ways
/// of saying "you typed". Facets spread the description across how you worked, when, and on what.
enum ActivityTag: String, Codable, CaseIterable {
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
    enum Facet: CaseIterable {
        case typing, pointer, efficiency, attention, rhythm, machine
    }

    var facet: Facet {
        switch self {
        case .steadyTyper, .burstTyper, .editorType: return .typing
        case .mouseExplorer, .scrollTraveler: return .pointer
        case .shortcutExpert, .pasteHeavy: return .efficiency
        case .focused, .appHopper, .chaotic: return .attention
        case .earlyBird, .nightOwl, .marathoner, .sprinter: return .rhythm
        case .unplugged, .multiScreen, .dataHeavy, .screenIdler: return .machine
        }
    }

    var label: String {
        switch self {
        case .steadyTyper: return "꾸준한 타이퍼"
        case .burstTyper: return "폭발형 타이퍼"
        case .editorType: return "수정형 타이퍼"
        case .mouseExplorer: return "마우스 탐험가"
        case .scrollTraveler: return "스크롤 여행자"
        case .shortcutExpert: return "단축키 전문가"
        case .pasteHeavy: return "복붙형"
        case .focused: return "집중형"
        case .appHopper: return "앱 호핑형"
        case .chaotic: return "혼돈형"
        case .earlyBird: return "아침형"
        case .nightOwl: return "야간형"
        case .marathoner: return "장시간형"
        case .sprinter: return "짧고 굵게형"
        case .unplugged: return "무선형"
        case .multiScreen: return "멀티스크린형"
        case .dataHeavy: return "데이터 헤비유저"
        case .screenIdler: return "켜두고 자리비움형"
        }
    }

    var emoji: String {
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
