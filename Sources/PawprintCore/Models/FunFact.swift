import Foundation

/// One "재미있는 사실" line, tagged with the quantity it describes.
///
/// The tag exists so the UI can show a varied selection: the conversion engine deliberately
/// produces many analogies per quantity (scroll height alone maps to stairs, floors, towers,
/// mountains), and showing five of them at once would read as one fact repeated five times.
package struct FunFact: Hashable, Identifiable {
    package enum Topic: String, CaseIterable {
        case cursor, scroll, typing, text, time, screen, pointer
        case energy, network, keys, apps, power, device, focus, misc
    }

    package let topic: Topic
    package let text: String

    package var id: String { text }
}
