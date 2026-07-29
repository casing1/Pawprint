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
final package class LocalizationManager {
    static package let shared = LocalizationManager()

    /// The pack keys are generated from, and the table consulted when a translation is missing.
    /// This is about *keys*, not about what the user sees first.
    static package let baseLanguage = "ko"

    /// What `.system` resolves to when macOS is set to a language Pawprint has no pack for.
    ///
    /// Deliberately not `baseLanguage`. The two were the same constant, which meant a Mac set to
    /// French or German — anything unlisted — opened in Korean. English is the reasonable guess
    /// for "some language we don't ship", and it is what the README and the repo default to.
    static package let fallbackLanguage = "en"

    /// The language to start in: the first of the user's preferred languages that has a pack,
    /// otherwise English.
    package nonisolated static var defaultCode: String {
        systemPreferredCode() ?? fallbackLanguage
    }

    /// Bumped on every language change purely so `@Observable` views re-render; the lookup
    /// itself reads `Tables`, not this.
    // `package var`, not `package private(set) var`. The two are equivalent to every caller here —
    // nothing outside this type assigns to them — but the Observation macro on the CI toolchain
    // copies the modifier list into its generated accessors and emits a duplicate, which is a
    // build failure rather than a warning. Keeping the setter package-visible is the smaller cost.
    package var revision: Int = 0
    package var languageCode: String = LocalizationManager.baseLanguage


    private init() {
        Tables.setBase(Self.loadPackFile(Self.baseLanguage))
        // Start on the system's language rather than on the base pack. Starting on the base pack
        // meant every string resolved before `apply` ran came out Korean, whoever you were.
        let code = Self.defaultCode
        Tables.setActive(code == Self.baseLanguage ? Tables.base : Self.loadPackFile(code), code: code)
        languageCode = code
    }

    /// Resolves `.system` against the user's preferred languages, falling back to the base pack
    /// when none of them has a pack.
    /// Returns true when the active pack actually changed, so the caller can rebuild anything
    /// that has already-translated text baked into it.
    @discardableResult
    package nonisolated func apply(_ language: AppLanguage) -> Bool {
        let resolved: String
        switch language {
        case .system:
            resolved = Self.defaultCode
        case .korean:
            resolved = "ko"
        case .english:
            resolved = "en"
        }
        guard resolved != Tables.activeCode else { return false }
        Tables.setActive(resolved == Self.baseLanguage ? Tables.base : Self.loadPackFile(resolved),
                         code: resolved)
        // The observable properties exist only to nudge SwiftUI, so they are touched on the main
        // actor while the lookup tables themselves are already swapped and lock-protected.
        Task { @MainActor in
            self.languageCode = resolved
            self.revision &+= 1
        }
        return true
    }

    /// First of the user's preferred languages that we actually ship a pack for.
    /// Korean groups large numbers by myriads and needs object particles; other packs don't.
    /// Keyed off the active pack rather than the system locale, so switching language in Settings
    /// changes number formatting too.
    package nonisolated static var usesMyriadGrouping: Bool { Tables.activeCode == "ko" }

    /// Locale for `DateFormatter`, following the active pack so weekday and month names match the
    /// rest of the UI instead of staying Korean.
    package nonisolated static var activeLocale: Locale {
        Locale(identifier: Tables.activeCode == "ko" ? "ko_KR" : "en_US")
    }

    package nonisolated static func systemPreferredCode() -> String? {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if AppLanguage.availableCodes.contains(code) { return code }
        }
        return nil
    }

    /// Deliberately avoids `Bundle.module`. SwiftPM's generated accessor **traps** when it can't
    /// find the resource bundle, and it looks beside the executable and at the absolute build
    /// directory — not in `Contents/Resources`, where an assembled .app puts it. Locally the build
    /// directory still existed so the app worked; the shipped build crashed on launch for
    /// everyone. Searching `Bundle.main` ourselves cannot trap and covers both layouts.
    package nonisolated static func loadPackFile(_ code: String) -> [String: String] {
        let name = code + ".json"
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("Localization/" + name))
            candidates.append(resources.appendingPathComponent(name))
            // The SwiftPM resource bundle, when it has been copied into the app.
            candidates.append(resources.appendingPathComponent("Pawprint_Pawprint.bundle/" + name))
            candidates.append(resources.appendingPathComponent("Pawprint_Pawprint.bundle/Localization/" + name))
        }
        // `swift run` and test runs, where the bundle sits beside the executable.
        let executableDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        candidates.append(executableDirectory.appendingPathComponent("Pawprint_Pawprint.bundle/" + name))

        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let parsed = try? JSONDecoder().decode([String: String].self, from: data)
            else { continue }
            return parsed
        }
        return [:]
    }
}

/// What the user can pick in Settings.
package enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system, korean, english

    static package let availableCodes: Set<String> = ["ko", "en"]

    package var label: String {
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
package enum Tables {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var activeTable: [String: String] = [:]
    nonisolated(unsafe) private static var baseTable: [String: String] = [:]
    nonisolated(unsafe) private static var loadedBase = false

    /// Loads the base pack on first lookup rather than relying on `LocalizationManager.shared`
    /// having been touched first. Static initialisers run in whatever order the app happens to
    /// reach them: `MetricCatalog.all` is built while decoding settings, which is *before* the
    /// manager exists, and it used to bake the raw keys in permanently.
    private static func ensureBaseLoaded() {
        guard !loadedBase else { return }
        loadedBase = true
        baseTable = LocalizationManager.loadPackFile(LocalizationManager.baseLanguage)
        guard activeTable.isEmpty else { return }
        // Reached when something resolves a string before `LocalizationManager.shared` exists.
        // It used to adopt the base pack, which showed Korean to everyone on this path; follow
        // the system language here too so the answer is the same either way round.
        let preferred = LocalizationManager.defaultCode
        activeTable = preferred == LocalizationManager.baseLanguage
            ? baseTable
            : LocalizationManager.loadPackFile(preferred)
        code = preferred
    }

    static package var base: [String: String] { lock.withLock { baseTable } }

    static package func setBase(_ table: [String: String]) {
        lock.withLock { baseTable = table; loadedBase = true }
    }
    nonisolated(unsafe) private static var code: String = ""

    static package var activeCode: String { lock.withLock { code } }

    static package func setActive(_ table: [String: String], code newCode: String = "") {
        lock.withLock { activeTable = table; code = newCode }
    }

    /// Falls back to the base pack so a partial translation degrades to Korean, never to a raw key.
    static package func lookup(_ key: String) -> String {
        lock.withLock {
            ensureBaseLoaded()
            return activeTable[key] ?? baseTable[key]
        } ?? key
    }
}

/// Lookup entry point. Short on purpose — it appears about 1,300 times.
package enum L10n {
    /// Returns the template for `key` in the active language, with `%@` placeholders replaced by
    /// `arguments` in order.
    ///
    /// Arguments are `Any` and stringified with `String(describing:)`, which reproduces exactly
    /// what Swift interpolation would have produced for the value that used to sit there — so the
    /// migration is behaviour-preserving for Int, Double, String and everything else alike.
    /// `String(format:)` is avoided deliberately: `%@` with a `CVarArg` bridge traps on anything
    /// that isn't an `NSObject`.
    static package func t(_ key: String, _ arguments: Any...) -> String {
        substitute(Tables.lookup(key), arguments.map { String(describing: $0) })
    }

    static package func substitute(_ template: String, _ arguments: [String]) -> String {
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
