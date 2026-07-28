import Foundation

/// A notice published by the project, shown in the popover until the user dismisses it.
///
/// Exists because some problems can only be explained, not fixed by shipping code — the Input
/// Monitoring failure is the case in point: a build can detect it and recover, but an install
/// whose permission entry is genuinely stale still needs a person to go and toggle it.
///
/// Title and body are per-language maps rather than plain strings. The text arrives from a file
/// on the network, so it cannot go through the app's language packs, and a notice that appears in
/// the wrong language is barely better than no notice.
struct Announcement: Codable, Identifiable, Equatable {
    let id: String
    /// `info` or `warning`; anything unrecognised is treated as `info`.
    var severity: String?
    /// "yyyy-MM-dd". Used only for ordering and for showing a date on the detail sheet.
    var publishedAt: String?
    /// Localised strings keyed by language code, with `en` as the fallback.
    var title: [String: String]
    var body: [String: String]
    /// Optional inclusive version bounds, so a notice about a specific broken build can be kept
    /// away from everyone else. Compared with `Announcement.compareVersions`.
    var minVersion: String?
    var maxVersion: String?
    /// Optional link shown on the detail sheet.
    var link: String?

    var isWarning: Bool { severity == "warning" }

    func title(for language: String) -> String { Self.pick(title, language) }
    func body(for language: String) -> String { Self.pick(body, language) }

    private static func pick(_ table: [String: String], _ language: String) -> String {
        table[language] ?? table["en"] ?? table.values.first ?? ""
    }

    /// True when `version` falls inside this announcement's bounds.
    func applies(to version: String) -> Bool {
        if let minVersion, Self.compareVersions(version, minVersion) < 0 { return false }
        if let maxVersion, Self.compareVersions(version, maxVersion) > 0 { return false }
        return true
    }

    /// Numeric component-wise comparison: -1, 0 or 1. String comparison would order "0.10.0"
    /// before "0.9.0".
    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let l = index < a.count ? a[index] : 0
            let r = index < b.count ? b[index] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }
}

/// The shape of the published feed.
struct AnnouncementFeed: Codable {
    var announcements: [Announcement]
}
