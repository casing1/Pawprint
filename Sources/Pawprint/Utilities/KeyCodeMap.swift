import Foundation

/// Maps macOS virtual key codes to coarse categories.
/// Never inspects `NSEvent.characters` — classification is keyCode-only so no typed text is ever observed.
enum KeyCodeMap {

    static func category(for keyCode: UInt16) -> KeyCategory {
        switch keyCode {
        case 0x24: return .enter
        case 0x30: return .tab
        case 0x31: return .space
        case 0x33: return .backspace
        case 0x75: return .delete
        case 0x35: return .escape
        case 0x7B, 0x7C, 0x7D, 0x7E: return .arrow
        case 0x37, 0x36: return .command
        case 0x38, 0x3C: return .shift
        case 0x3A, 0x3D: return .option
        case 0x3B, 0x3E: return .control
        case 0x39: return .capsLock
        case 0x66, 0x68: return .hangulSwitch
        case 0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40:
            return .functionKey
        default:
            return .character
        }
    }

    /// ANSI letter/digit keyCodes used only to detect well-known global shortcut chords (Cmd+C, Cmd+V, ...).
    /// Still never reads the typed character — only whether *this specific* keyCode + modifier combo fired.
    enum ANSI {
        static let a: UInt16 = 0x00
        static let c: UInt16 = 0x08
        static let v: UInt16 = 0x09
        static let x: UInt16 = 0x07
        static let z: UInt16 = 0x06
        static let y: UInt16 = 0x10
        static let three: UInt16 = 0x14
        static let four: UInt16 = 0x15
        static let five: UInt16 = 0x17
    }

    static let tabKeyCode: UInt16 = 0x30
    static let spaceKeyCode: UInt16 = 0x31
}

enum KeyCategory: String, Codable, CaseIterable {
    case character
    case backspace
    case delete
    case escape
    case enter
    case space
    case tab
    case arrow
    case shift
    case command
    case option
    case control
    case capsLock
    case hangulSwitch
    case functionKey
}
