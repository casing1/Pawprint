import Foundation
import UserNotifications

/// Local notifications: a once-a-day summary at a time the user picks, plus quiet celebrations
/// for level-ups and personal records.
///
/// Everything here is opt-in and off by default. Per the spec's "사용자를 압박하지 않는다" rule
/// there are no nags, no goals, and nothing fires more than once a day — the daily note is a
/// recap of what happened, never a prompt to do more.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private enum Identifier {
        static let dailySummary = "pawprint.daily.summary"
        static let celebration = "pawprint.celebration"
    }

    private init() {}

    // MARK: - Permission

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Daily summary

    /// Schedules (or reschedules) the repeating daily summary. The body is written when the
    /// notification is scheduled, so it describes *yesterday's* shape of day in general terms;
    /// exact numbers are refreshed each time this is called.
    func scheduleDailySummary(hour: Int, minute: Int, summary: DailySummary) async {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.dailySummary])
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.t("notificationManager.0bd1f05d")
        content.body = Self.dailyBody(for: summary)
        content.sound = nil   // a summary shouldn't interrupt anything

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: Identifier.dailySummary,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelDailySummary() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.dailySummary])
    }

    static func dailyBody(for summary: DailySummary) -> String {
        guard summary.activeSeconds > 0 else {
            return L10n.t("notificationManager.86e5eb59")
        }
        var parts: [String] = []
        if let score = summary.score {
            parts.append(L10n.t("notificationManager.79ca0623", score.grade, score.headline))
        }
        parts.append(L10n.t("notificationManager.6cee1183", Formatters.compactDuration(summary.activeSeconds)))
        if summary.totalKeyPresses > 0 {
            parts.append(L10n.t("notificationManager.a7c3c02f", Formatters.compactNumber(summary.totalKeyPresses)))
        }
        if summary.longestFocusSeconds >= 300 {
            parts.append(L10n.t("notificationManager.ba31f788", Formatters.compactDuration(summary.longestFocusSeconds)))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Celebrations

    /// Posts one achievement notification.
    ///
    /// Rate limiting lives with the caller (`ActivityCenter.announceLevelUps`) because it has to
    /// persist across launches, and an in-memory "already fired today" flag here reset on every
    /// restart — which is exactly how the same alert kept coming back.
    func announce(title: String, body: String) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: Identifier.celebration + "." + UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }
}
