import XCTest
import PawprintCore
@testable import Pawprint

/// What every language pack has to be true of, whatever state its translation is in.
///
/// The packs are hand-written JSON, and the two mistakes that matter are silent: a translation that
/// drops a `%@` renders the wrong number of values into the wrong places, and a key that exists in
/// no pack shows a raw hash to somebody. Both are cheap to check and impossible to notice by
/// reading.
final class LanguagePackTests: XCTestCase {

    /// Read from the repository rather than through `loadPackFile`, which searches `Bundle.main` —
    /// and `Bundle.main` under `swift test` is the test runner, which carries no packs. The files
    /// are the thing being checked, so reading them is also the more direct question.
    private static let packDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // PawprintTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repository root
        .appendingPathComponent("Sources/Pawprint/Resources/Localization")

    private func pack(_ code: String) throws -> [String: String] {
        let url = Self.packDirectory.appendingPathComponent("\(code).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    /// Every language the picker offers has a file behind it.
    func testEveryOfferedLanguageHasAPack() throws {
        for language in AppLanguage.allCases {
            guard let code = language.code else { continue }
            XCTAssertTrue(AppLanguage.availableCodes.contains(code),
                          "\(language) is offered but not in availableCodes")
            XCTAssertFalse(try pack(code).isEmpty, "\(code).json is empty")
        }
    }

    /// A translation must render exactly the values its English original does. One `%@` too few
    /// silently drops a number; one too many renders garbage into the sentence.
    func testPlaceholdersMatchEnglish() throws {
        let english = try pack("en")
        for code in AppLanguage.availableCodes where code != "en" {
            for (key, translated) in try pack(code) {
                guard let original = english[key] else { continue }
                XCTAssertEqual(translated.components(separatedBy: "%@").count,
                               original.components(separatedBy: "%@").count,
                               "\(code) \(key): '%@' count differs from English")
                for specifier in ["%.0f", "%.1f", "%d"] {
                    XCTAssertEqual(translated.contains(specifier), original.contains(specifier),
                                   "\(code) \(key): '\(specifier)' differs from English")
                }
            }
        }
    }

    /// A pack may be incomplete — that is what the English fallback is for — but it may not contain
    /// keys that exist nowhere else, which are typos rather than translations.
    func testNoPackInventsKeys() throws {
        let korean = try pack("ko")
        for code in AppLanguage.availableCodes where code != "ko" {
            let unknown = try pack(code).keys.filter { korean[$0] == nil }.sorted()
            XCTAssertTrue(unknown.isEmpty, "\(code) has keys no other pack knows: \(unknown.prefix(5))")
        }
    }

    /// Korean is the base and is what everything falls back through, so it must be complete.
    func testTheBasePackIsComplete() throws {
        let korean = try pack("ko")
        let english = try pack("en")
        XCTAssertEqual(Set(korean.keys), Set(english.keys),
                       "the base and English packs have drifted apart")
    }

    /// Reports where each translation stands, so its coverage is a number rather than an
    /// impression. Not an assertion — a partial pack is a valid state, it just needs to be visible.
    func testCoverageIsReported() throws {
        let korean = try pack("ko")
        for code in AppLanguage.availableCodes.sorted() {
            let table = try pack(code)
            let covered = korean.keys.filter { table[$0] != nil }.count
            print("\(code): \(covered)/\(korean.count) keys "
                  + "(\(covered * 100 / max(1, korean.count))%)")
        }
    }
}
