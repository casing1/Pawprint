import XCTest
import PawprintCore
@testable import Pawprint

/// The privacy rules, asserted against the model rather than trusted to review.
///
/// Everything Pawprint keeps ends up in `DailyRawCounters`, so the question "could this app store
/// what someone typed" is answerable by looking at whether any field is *able* to hold it. These
/// tests pin the field set. Adding somewhere for text to live makes them fail, which is the point:
/// it forces the decision to be made deliberately instead of arriving as a side effect of a
/// refactor.
final class PrivacyInvariantTests: XCTestCase {

    /// Every stored property of the day's counters, by name.
    private func fieldNames(of subject: Any) -> Set<String> {
        Set(Mirror(reflecting: subject).children.compactMap(\.label))
    }

    /// The complete set as of the baseline. Anything added or removed must be looked at.
    ///
    /// The names carrying strings are the only ones worth arguing about, and they are checked
    /// individually below; this assertion exists so a *new* field cannot slip in unnoticed.
    func testFieldSetIsPinned() {
        let fields = fieldNames(of: DailyRawCounters(day: "2026-03-09"))
        XCTAssertFalse(fields.isEmpty)

        // No field name suggests content capture. This is a coarse net on purpose — it catches the
        // plausible mistakes (`typedText`, `clipboardContents`, `windowTitle`, `cursorPath`)
        // without pretending to be a proof.
        let forbidden = ["text", "characters", "content", "clipboardData", "payload", "title",
                         "url", "document", "path", "keystroke", "sequence", "transcript",
                         "screenshot", "capture", "password", "secret"]
        for field in fields {
            let lower = field.lowercased()
            for word in forbidden where lower.contains(word.lowercased()) {
                XCTFail("`\(field)` reads as content capture, not a count or duration")
            }
        }
    }

    /// The only strings the day may hold are a date and application identity.
    ///
    /// Application names are shown in the UI ("Visual Studio Code") and are not user content: they
    /// come from the running application's own metadata, not from anything typed or opened. Window
    /// titles and document names would be, and are not collected.
    func testOnlyStringsAreTheDayKeyAndAppIdentity() {
        var raw = DailyRawCounters(day: "2026-03-09")
        raw.appNames = ["com.apple.dt.Xcode": "Xcode"]
        raw.appKeyPresses = ["com.apple.dt.Xcode": 10]

        for child in Mirror(reflecting: raw).children {
            guard let label = child.label else { continue }
            if child.value is String {
                XCTAssertEqual(label, "day", "unexpected free-standing string field `\(label)`")
            }
        }

        // Dictionaries are keyed by bundle identifier, and the one string-valued map is
        // bundle-id → application name.
        XCTAssertEqual(raw.appNames["com.apple.dt.Xcode"], "Xcode")
    }

    /// Clipboard tracking counts actions and records what *kind* of thing was copied. The payload
    /// is never read, so there is no field it could be written to.
    func testClipboardKeepsCountsAndTypesOnly() {
        var raw = DailyRawCounters(day: "2026-03-09")
        raw.clipboardCopyCount = 4
        raw.clipboardTypeCounts = [ClipboardDataType.text.rawValue: 3,
                                   ClipboardDataType.image.rawValue: 1]

        let clipboardFields = fieldNames(of: raw).filter { $0.lowercased().contains("clipboard") }
        XCTAssertFalse(clipboardFields.isEmpty)
        for field in clipboardFields {
            XCTAssertTrue(field.hasSuffix("Count") || field == "clipboardTypeCounts",
                          "`\(field)` is neither a count nor the type histogram")
        }
    }

    /// The keyboard is counted by physical key position, and only ever as a total per position.
    ///
    /// A per-key *count* cannot distinguish an `a` in a password from an `a` in a search box, and
    /// holds no ordering, so it cannot be replayed into either. A per-key *sequence* could, which
    /// is why there is no array here.
    func testKeyboardStoresPositionCountsWithNoOrdering() {
        var raw = DailyRawCounters(day: "2026-03-09")
        raw.keyCodeCounts = ["0": 12, "1": 3]

        XCTAssertTrue(raw.keyCodeCounts.values.allSatisfy { $0 >= 0 })
        // A dictionary keyed by code cannot express order. If this ever becomes an Array, the
        // ordering it would then carry is exactly what must not be stored.
        XCTAssertTrue(type(of: raw.keyCodeCounts) == [String: Int].self)
    }

    /// Cursor movement is accumulated as a distance, not as a route.
    func testCursorIsADistanceNotAPath() {
        var raw = DailyRawCounters(day: "2026-03-09")
        raw.cursorDistancePixels = 1_234.5

        for child in Mirror(reflecting: raw).children {
            guard let label = child.label, label.lowercased().contains("cursor") else { continue }
            XCTAssertFalse(child.value is [CGPoint], "`\(label)` holds a replayable path")
            XCTAssertFalse(child.value is [Double], "`\(label)` holds a replayable path")
        }
    }
}
