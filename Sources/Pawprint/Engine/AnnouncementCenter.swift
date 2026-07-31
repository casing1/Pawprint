import Foundation
import Observation
import PawprintCore

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

    /// Everything still worth showing: applies to this version, not dismissed, newest first.
    var visible: [Announcement] {
        let version = UpdateChecker.shared.currentVersion
        let dismissed = Set(ActivityCenter.shared.settings.dismissedAnnouncements)
        return announcements
            .filter { !dismissed.contains($0.id) && $0.applies(to: version) }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    /// Which of `visible` the banner is currently on.
    ///
    /// Only the newest used to be shown, so a second undismissed notice sat behind the first and
    /// was never seen — and since the only way to clear a notice is to dismiss it deliberately,
    /// the one behind could wait indefinitely.
    private(set) var rotationIndex = 0

    /// The notice to show, or nil.
    var current: Announcement? {
        let items = visible
        guard !items.isEmpty else { return nil }
        return items[rotationIndex % items.count]
    }

    /// How many are waiting, for the banner's position dots.
    var visibleCount: Int { visible.count }

    /// Moves to the next notice. Called on a timer while the popover is open, and once each time
    /// it opens — a popover is often shut again within a few seconds, so waiting purely on the
    /// timer would mean short visits always showed the same one.
    func advance() {
        let count = visibleCount
        guard count > 1 else { return }
        rotationIndex = (rotationIndex + 1) % count
    }

    static let rotationInterval: TimeInterval = 8

    /// Verification only.
    func resetRotationForTesting() { rotationIndex = 0 }

    @ObservationIgnored private var rotationTimer: Timer?

    /// Rotates while the banner is on screen. Pointless with one notice, and pointless while the
    /// popover is closed, so it is started and stopped by the banner's lifecycle.
    func startRotation() {
        stopRotation()
        guard visibleCount > 1 else { return }
        let timer = Timer(timeInterval: Self.rotationInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }

    func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
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
        // The list just got shorter; land on a valid entry rather than wherever the old index
        // happens to point, and stop rotating if only one is left.
        rotationIndex = 0
        startRotation()
    }

    func refresh() async {
        // The update check fires a few seconds after launch and would repopulate the feed part
        // way through a capture run, putting a live notice over whichever tab was being shot.
        guard !CaptureMode.isActive else { return }
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
