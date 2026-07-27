import CryptoKit
import Foundation

/// Optional, anonymous "this install ran today" ping, so the project can tell how many people
/// actually use Pawprint rather than only how many downloaded it.
///
/// **Nothing is sent unless an endpoint is configured *and* the setting is on.** A build with no
/// endpoint — which is what ships by default — never opens a connection, so the app stays exactly
/// as offline as it was. See `docs/ANALYTICS.md` for deploying one.
///
/// The whole payload is four short strings:
///
///   * `day` / `month` — rotating hashes, described below
///   * `version` — the app's marketing version
///   * `os` — the macOS major version, e.g. "26"
///
/// **No stable identifier ever leaves the machine.** The install ID is a random UUID generated
/// locally, and it is never transmitted: what goes out is `SHA256(installID + date)`, truncated.
/// The server counts distinct hashes for a day to get daily actives, and distinct month hashes to
/// get monthly actives — but two pings from the same install on different days share no value, so
/// the data cannot be joined into a history of when any one person used their Mac. That property
/// is the reason for the rotation; a plain install ID would have been simpler and worse.
///
/// Deliberately absent: any counter, any metric, anything about *how* the Mac was used. Those are
/// the thing the app promises never to transmit, and an analytics endpoint is exactly where that
/// promise would erode first.
@MainActor
enum UsageReporter {

    /// Sends at most one ping per calendar day.
    static func reportIfDue() {
        var settings = ActivityCenter.shared.settings
        guard settings.usageStatsEnabled else { return }

        let endpoint = settings.usageStatsEndpoint.trimmingCharacters(in: .whitespaces)
        guard !endpoint.isEmpty, let url = URL(string: endpoint.hasSuffix("/") ? endpoint + "ping" : endpoint + "/ping"),
              url.scheme == "https"
        else { return }

        let today = Self.dayString()
        guard settings.lastUsagePingDay != today else { return }

        // A fresh random identity, kept on this Mac only, so the rotating hashes below are stable
        // within a day without anything about the user going into them.
        if settings.installID.isEmpty { settings.installID = UUID().uuidString }

        let body: [String: String] = [
            "day": rotatingHash(settings.installID, salt: today),
            "month": rotatingHash(settings.installID, salt: String(today.prefix(7))),
            "version": Self.appVersion,
            "os": String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }

        // Marked sent before the request rather than after. A server that is down or slow must not
        // turn into a retry every few minutes for the rest of the day; missing a day's count is a
        // far smaller problem than hammering an endpoint from every install at once.
        settings.lastUsagePingDay = today
        ActivityCenter.shared.updateSettings(settings)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request).resume()
    }

    /// `SHA256(installID + salt)`, first 16 hex characters — plenty to avoid collisions among any
    /// plausible number of installs, short enough to be obviously not a payload.
    static func rotatingHash(_ installID: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((installID + ":" + salt).utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    /// UTC, not the user's day-start preference: this is a server-side bucketing key, and a
    /// timezone-dependent one would make the counts depend on where people live.
    static func dayString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
