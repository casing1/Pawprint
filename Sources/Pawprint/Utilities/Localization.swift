import Foundation
import Observation

/// Runtime localization backed by JSON language packs.
///
/// Deliberately *not* `Localizable.strings` + `Bundle`: the system mechanism resolves the
/// language once at launch from the user's system settings, so an in-app language picker would
/// need a relaunch to take effect. Loading flat JSON ourselves means switching language redraws
/// the UI immediately, and a translator can edit one readable file without touching Xcode.
///
/// Packs live in `Resources/Localization/<code>.json` as a flat `key: template` map. Templates
/// use `%@` placeholders, filled positionally by `L10n.t`.
///
/// **Adding a language:** drop in `Resources/Localization/<code>.json`, translating the values of
/// `ko.json`, and add the code to `AppLanguage`. Missing keys fall back to the base language, so a
/// partial translation degrades to Korean rather than showing raw keys.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    /// The pack every other language falls back to, and the one keys are generated from.
    static let baseLanguage = "ko"

    /// Bumped on every language change purely so `@Observable` views re-render; the lookup
    /// itself reads `Tables`, not this.
    private(set) var revision: Int = 0
    private(set) var languageCode: String = LocalizationManager.baseLanguage

    private init() {
        Tables.setBase(Self.loadPack(Self.baseLanguage))
        Tables.setActive(Tables.base, code: Self.baseLanguage)
    }

    /// Resolves `.system` against the user's preferred languages, falling back to the base pack
    /// when none of them has a pack.
    nonisolated func apply(_ language: AppLanguage) {
        let resolved: String
        switch language {
        case .system:
            resolved = Self.systemPreferredCode() ?? Self.baseLanguage
        case .korean:
            resolved = "ko"
        case .english:
            resolved = "en"
        }
        guard resolved != Tables.activeCode else { return }
        Tables.setActive(resolved == Self.baseLanguage ? Tables.base : Self.loadPack(resolved),
                         code: resolved)
        // The observable properties exist only to nudge SwiftUI, so they are touched on the main
        // actor while the lookup tables themselves are already swapped and lock-protected.
        Task { @MainActor in
            self.languageCode = resolved
            self.revision &+= 1
        }
    }

    /// First of the user's preferred languages that we actually ship a pack for.
    /// Korean groups large numbers by myriads and needs object particles; other packs don't.
    /// Keyed off the active pack rather than the system locale, so switching language in Settings
    /// changes number formatting too.
    nonisolated static var usesMyriadGrouping: Bool { Tables.activeCode == "ko" }

    /// Locale for `DateFormatter`, following the active pack so weekday and month names match the
    /// rest of the UI instead of staying Korean.
    nonisolated static var activeLocale: Locale {
        Locale(identifier: Tables.activeCode == "ko" ? "ko_KR" : "en_US")
    }

    nonisolated static func systemPreferredCode() -> String? {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if AppLanguage.availableCodes.contains(code) { return code }
        }
        return nil
    }

    nonisolated private static func loadPack(_ code: String) -> [String: String] {
        guard let url = Bundle.module.url(forResource: code, withExtension: "json",
                                          subdirectory: "Localization")
                ?? Bundle.module.url(forResource: code, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return parsed
    }
}

/// What the user can pick in Settings.
enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system, korean, english

    static let availableCodes: Set<String> = ["ko", "en"]

    var label: String {
        switch self {
        case .system: return L10n.t("settings.language.system")
        case .korean: return "한국어"
        case .english: return "English"
        }
    }
}

/// The loaded packs, held outside the `@MainActor` manager so `L10n.t` can be called from
/// anywhere — engines and formatters build text off the main actor, and annotating all ~1,300
/// call sites would be far worse than a lock around two dictionary reads.
enum Tables {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var activeTable: [String: String] = [:]
    nonisolated(unsafe) private static var baseTable: [String: String] = [:]

    static var base: [String: String] { lock.withLock { baseTable } }

    static func setBase(_ table: [String: String]) { lock.withLock { baseTable = table } }
    nonisolated(unsafe) private static var code: String = ""

    static var activeCode: String { lock.withLock { code } }

    static func setActive(_ table: [String: String], code newCode: String = "") {
        lock.withLock { activeTable = table; code = newCode }
    }

    /// Falls back to the base pack so a partial translation degrades to Korean, never to a raw key.
    static func lookup(_ key: String) -> String {
        lock.withLock { activeTable[key] ?? baseTable[key] } ?? key
    }
}

/// Lookup entry point. Short on purpose — it appears about 1,300 times.
enum L10n {
    /// Returns the template for `key` in the active language, with `%@` placeholders replaced by
    /// `arguments` in order.
    ///
    /// Arguments are `Any` and stringified with `String(describing:)`, which reproduces exactly
    /// what Swift interpolation would have produced for the value that used to sit there — so the
    /// migration is behaviour-preserving for Int, Double, String and everything else alike.
    /// `String(format:)` is avoided deliberately: `%@` with a `CVarArg` bridge traps on anything
    /// that isn't an `NSObject`.
    static func t(_ key: String, _ arguments: Any...) -> String {
        substitute(Tables.lookup(key), arguments.map { String(describing: $0) })
    }

    static func substitute(_ template: String, _ arguments: [String]) -> String {
        guard !arguments.isEmpty else { return template }
        var result = ""
        var index = 0
        var rest = Substring(template)
        while let range = rest.range(of: "%@") {
            result += rest[rest.startIndex..<range.lowerBound]
            result += index < arguments.count ? arguments[index] : "%@"
            index += 1
            rest = rest[range.upperBound...]
        }
        result += rest
        return result
    }
}
