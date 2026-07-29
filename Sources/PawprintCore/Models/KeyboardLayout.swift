import Foundation

/// Physical description of a US-ANSI Mac keyboard, used to draw the heatmap.
///
/// Positions are in "key units" (1u = one standard key width) so the view can scale freely.
/// Labels are the legend printed on the physical key — they describe *where the key is on the
/// board*, not what the user typed. Pawprint never reads the character an event produced.
package struct KeyboardKey: Identifiable {
    package var keyCode: UInt16
    package var label: String
    /// Position and size in key units, origin top-left.
    package var x: Double
    package var y: Double
    package var width: Double = 1
    package var height: Double = 1
    package var hand: Hand
    package var row: Row

    package var id: UInt16 { keyCode }

    package enum Hand { case left, right, either }
    package enum Row: String, CaseIterable {
        case number, top, home, bottom, modifier, function

        package var label: String {
            switch self {
            case .number: return L10n.t("keyboardLayout.382df18b")
            case .top: return L10n.t("keyboardLayout.b57c685e")
            case .home: return L10n.t("keyboardLayout.79c2aafd")
            case .bottom: return L10n.t("keyboardLayout.9c54d341")
            case .modifier: return L10n.t("keyboardLayout.3104b91a")
            case .function: return L10n.t("keyboardLayout.05500807")
            }
        }
    }
}

package enum KeyboardLayout {
    static package let unitsWide: Double = 15.0
    static package let unitsTall: Double = 6.0

    /// US-ANSI layout. Key codes are macOS virtual key codes (`kVK_*`).
    static package let keys: [KeyboardKey] = {
        var keys: [KeyboardKey] = []

        // Number row
        let numberRow: [(UInt16, String)] = [
            (0x32, "`"), (0x12, "1"), (0x13, "2"), (0x14, "3"), (0x15, "4"), (0x17, "5"),
            (0x16, "6"), (0x1A, "7"), (0x1C, "8"), (0x19, "9"), (0x1D, "0"),
            (0x1B, "-"), (0x18, "="),
        ]
        for (index, entry) in numberRow.enumerated() {
            keys.append(KeyboardKey(
                keyCode: entry.0, label: entry.1,
                x: Double(index), y: 0,
                hand: index <= 5 ? .left : .right, row: .number
            ))
        }
        keys.append(KeyboardKey(keyCode: 0x33, label: "⌫", x: 13, y: 0, width: 2, hand: .right, row: .number))

        // Top letter row
        keys.append(KeyboardKey(keyCode: 0x30, label: "⇥", x: 0, y: 1, width: 1.5, hand: .left, row: .top))
        let topRow: [(UInt16, String)] = [
            (0x0C, "Q"), (0x0D, "W"), (0x0E, "E"), (0x0F, "R"), (0x11, "T"),
            (0x10, "Y"), (0x20, "U"), (0x22, "I"), (0x1F, "O"), (0x23, "P"),
            (0x21, "["), (0x1E, "]"), (0x2A, "\\"),
        ]
        for (index, entry) in topRow.enumerated() {
            keys.append(KeyboardKey(
                keyCode: entry.0, label: entry.1,
                x: 1.5 + Double(index), y: 1,
                width: index == topRow.count - 1 ? 1.5 : 1,
                hand: index <= 4 ? .left : .right, row: .top
            ))
        }

        // Home row
        keys.append(KeyboardKey(keyCode: 0x39, label: "⇪", x: 0, y: 2, width: 1.75, hand: .left, row: .modifier))
        let homeRow: [(UInt16, String)] = [
            (0x00, "A"), (0x01, "S"), (0x02, "D"), (0x03, "F"), (0x05, "G"),
            (0x04, "H"), (0x26, "J"), (0x28, "K"), (0x25, "L"), (0x29, ";"), (0x27, "'"),
        ]
        for (index, entry) in homeRow.enumerated() {
            keys.append(KeyboardKey(
                keyCode: entry.0, label: entry.1,
                x: 1.75 + Double(index), y: 2,
                hand: index <= 4 ? .left : .right, row: .home
            ))
        }
        keys.append(KeyboardKey(keyCode: 0x24, label: "⏎", x: 12.75, y: 2, width: 2.25, hand: .right, row: .home))

        // Bottom letter row
        keys.append(KeyboardKey(keyCode: 0x38, label: "⇧", x: 0, y: 3, width: 2.25, hand: .left, row: .modifier))
        let bottomRow: [(UInt16, String)] = [
            (0x06, "Z"), (0x07, "X"), (0x08, "C"), (0x09, "V"), (0x0B, "B"),
            (0x2D, "N"), (0x2E, "M"), (0x2B, ","), (0x2F, "."), (0x2C, "/"),
        ]
        for (index, entry) in bottomRow.enumerated() {
            keys.append(KeyboardKey(
                keyCode: entry.0, label: entry.1,
                x: 2.25 + Double(index), y: 3,
                hand: index <= 4 ? .left : .right, row: .bottom
            ))
        }
        keys.append(KeyboardKey(keyCode: 0x3C, label: "⇧", x: 12.25, y: 3, width: 2.75, hand: .right, row: .modifier))

        // Modifier / space row
        keys.append(KeyboardKey(keyCode: 0x3B, label: "⌃", x: 0, y: 4, width: 1.25, hand: .left, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x3A, label: "⌥", x: 1.25, y: 4, width: 1.25, hand: .left, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x37, label: "⌘", x: 2.5, y: 4, width: 1.5, hand: .left, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x31, label: "space", x: 4, y: 4, width: 5.5, hand: .either, row: .bottom))
        keys.append(KeyboardKey(keyCode: 0x36, label: "⌘", x: 9.5, y: 4, width: 1.5, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x3D, label: "⌥", x: 11, y: 4, width: 1.25, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x3E, label: "⌃", x: 12.25, y: 4, width: 1.25, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x7B, label: "←", x: 13.5, y: 4, width: 0.5, height: 1, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x7C, label: "→", x: 14.5, y: 4, width: 0.5, height: 1, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x7E, label: "↑", x: 14, y: 4, width: 0.5, height: 0.5, hand: .right, row: .modifier))
        keys.append(KeyboardKey(keyCode: 0x7D, label: "↓", x: 14, y: 4.5, width: 0.5, height: 0.5, hand: .right, row: .modifier))

        // Escape lives on its own row above the numbers, matching real hardware. Function keys
        // aren't tracked individually, so the rest of that row is left empty.
        keys = keys.map { key in
            var shifted = key
            shifted.y += 1
            return shifted
        }
        keys.append(KeyboardKey(keyCode: 0x35, label: "esc", x: 0, y: 0, width: 1, hand: .left, row: .function))

        return keys
    }()

    /// Fast lookup for the "most-pressed key" readout.
    static package let labelsByKeyCode: [UInt16: String] = {
        Dictionary(keys.map { ($0.keyCode, $0.label) }, uniquingKeysWith: { first, _ in first })
    }()

    static package func label(for keyCode: UInt16) -> String? {
        labelsByKeyCode[keyCode]
    }
}
