import SwiftUI
import PawprintCore
import UserNotifications

/// The daily summary and level-up notices — opt-in, capped, and never a nudge to work more.
@MainActor
struct NotificationSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter
    @State private var authorizationNote: String?
    @State private var status: UNAuthorizationStatus = .notDetermined

    private var summaryTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = activityCenter.settings.dailySummaryHour
                components.minute = activityCenter.settings.dailySummaryMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                var s = activityCenter.settings
                s.dailySummaryHour = parts.hour ?? 21
                s.dailySummaryMinute = parts.minute ?? 0
                activityCenter.updateSettings(s)
                rescheduleIfEnabled()
            }
        )
    }

    var body: some View {
        Form {
            Section(L10n.t("settingsRootView.613263b3")) {
                Toggle(L10n.t("settingsRootView.2fa70c01"), isOn: Binding(
                    get: { activityCenter.settings.dailySummaryEnabled },
                    set: { isOn in
                        var s = activityCenter.settings
                        s.dailySummaryEnabled = isOn
                        activityCenter.updateSettings(s)
                        Task { await apply(enabled: isOn) }
                    }
                ))
                DatePicker(L10n.t("settingsRootView.94c2756c"), selection: summaryTime, displayedComponents: .hourAndMinute)
                    .disabled(!activityCenter.settings.dailySummaryEnabled)
                Text(L10n.t("settingsRootView.57ce5282"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Section(L10n.t("settingsRootView.99e19534")) {
                Toggle(L10n.t("settingsRootView.e5d5e106"), isOn: Binding(
                    get: { activityCenter.settings.celebrationNotificationsEnabled },
                    set: { isOn in
                        var s = activityCenter.settings
                        s.celebrationNotificationsEnabled = isOn
                        activityCenter.updateSettings(s)
                        if isOn { Task { _ = await NotificationManager.shared.requestAuthorizationIfNeeded() } }
                    }
                ))
                Text(L10n.t("settingsRootView.08f28613", AppSettings.maxAchievementNotificationsPerDay))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Section(L10n.t("settingsRootView.7429b001")) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                    Text(statusText).font(.callout)
                    Spacer()
                }
                HStack {
                    Button(L10n.t("settingsRootView.dfd24172")) { Task { await refreshStatus() } }
                    Button(L10n.t("settingsRootView.a53aa7ea")) { openNotificationSettings() }
                    Spacer()
                }
                if let authorizationNote {
                    Text(authorizationNote).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await refreshStatus() }
    }

    private var statusIcon: String {
        switch status {
        case .authorized, .provisional: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .provisional: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    private var statusText: String {
        switch status {
        case .authorized: return L10n.t("settingsRootView.069f7a37")
        case .provisional: return L10n.t("settingsRootView.c62e4186")
        case .denied: return L10n.t("settingsRootView.cf33ef6f")
        case .notDetermined: return L10n.t("settingsRootView.88fb55f1")
        @unknown default: return L10n.t("settingsRootView.c36d25c1")
        }
    }

    private func refreshStatus() async {
        status = await NotificationManager.shared.authorizationStatus()
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func apply(enabled: Bool) async {
        defer { Task { await refreshStatus() } }
        guard enabled else {
            NotificationManager.shared.cancelDailySummary()
            authorizationNote = nil
            return
        }
        let granted = await NotificationManager.shared.requestAuthorizationIfNeeded()
        guard granted else {
            authorizationNote = L10n.t("settingsRootView.d22e58d7")
            return
        }
        authorizationNote = nil
        rescheduleIfEnabled()
    }

    private func rescheduleIfEnabled() {
        let settings = activityCenter.settings
        guard settings.dailySummaryEnabled else { return }
        let summary = activityCenter.todaySummary
        Task {
            await NotificationManager.shared.scheduleDailySummary(
                hour: settings.dailySummaryHour,
                minute: settings.dailySummaryMinute,
                summary: summary
            )
        }
    }
}

// MARK: - Data
