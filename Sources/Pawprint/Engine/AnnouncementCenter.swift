import Foundation
import Observation

/// Fetches project notices and remembers which ones have been dismissed.
///
/// Rides on the update check rather than being its own feature: it uses the same consent
/// (`updateCheckEnabled`), the same cadence, and the same fixed host. Turning update checks off
/// still leaves the app completely offline.
///
/// Dismissal is deliberate and permanent — a notice keeps showing on every launch until the user
/// presses "don't show again". Reading it is not dismissing it: the whole reason to publish one is
/// that it asks the reader to go and do something, and a banner that vanishes on sight would be
/// missed by exactly the people who most need it.
@MainActor
@Observable
final class AnnouncementCenter {
    static let shared = AnnouncementCenter()

    /// Fixed, like the update feed. Not a setting.
    static let feedURL = "https://raw.githubusercontent.com/yhcho0405/Pawprint/main/docs/announcements.json"

    /// Not `private(set)`: the verification probe seeds it directly rather than going over the
    /// network, so the dismissal rules can be exercised without a live feed.
    var announcements: [Announcement] = []

    private init() {}

    /// The notice to show, or nil. Newest first among those that apply and aren't dismissed.
    var current: Announcement? {
        let version = UpdateChecker.shared.currentVersion
        let dismissed = Set(ActivityCenter.shared.settings.dismissedAnnouncements)
        return announcements
            .filter { !dismissed.contains($0.id) && $0.applies(to: version) }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
            .first
    }

    func dismiss(_ announcement: Announcement) {
        var settings = ActivityCenter.shared.settings
        guard !settings.dismissedAnnouncements.contains(announcement.id) else { return }
        settings.dismissedAnnouncements.append(announcement.id)
        // Bounded: only ids ever published can accumulate here, but there is no reason to keep
        // them forever either.
        if settings.dismissedAnnouncements.count > 100 {
            settings.dismissedAnnouncements.removeFirst(settings.dismissedAnnouncements.count - 100)
        }
        ActivityCenter.shared.updateSettings(settings)
    }

    func refresh() async {
        guard ActivityCenter.shared.settings.updateCheckEnabled else { return }
        guard let url = URL(string: Self.feedURL) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // The feed is a static file on a CDN; without this the OS cache can serve a stale copy
        // for hours, which for a notice about a live problem is the wrong trade.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(AnnouncementFeed.self, from: data)
        else { return }
        announcements = feed.announcements
    }
}
