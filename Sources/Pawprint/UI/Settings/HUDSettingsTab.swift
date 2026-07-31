import SwiftUI
import PawprintCore

/// The floating session panel: whether it appears, and what it shows.
@MainActor
struct HUDSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        Form {
            Section {
                HStack {
                    Button(LiveHUDController.shared.isVisible ? L10n.t("settingsRootView.14cf7d17") : L10n.t("settingsRootView.953a6727"))
                        { LiveHUDController.shared.toggle() }
                    Spacer()
                }
                Toggle(L10n.t("settingsRootView.e9a8a0f8"), isOn: Binding(
                    get: { activityCenter.settings.hudCompact },
                    set: { activityCenter.setHUDCompact($0) }
                ))
            }

            Section(L10n.t("settingsRootView.9723170d")) {
                Toggle(L10n.t("settingsRootView.046d22be"), isOn: activityCenter.binding(\.hudShowsSessionTime))
                Toggle(L10n.t("settingsRootView.567fb32a"), isOn: activityCenter.binding(\.hudShowsSessionKeys))
                Toggle(L10n.t("settingsRootView.ec433402"), isOn: activityCenter.binding(\.hudShowsSessionClicks))
            }

            Section(L10n.t("settingsRootView.f2646959", AppSettings.maxHUDMetrics)) {
                // Same catalog-driven pattern as the other pickers.
                ForEach(MetricCatalog.enabled(MetricCatalog.all, settings: activityCenter.settings)) { metric in
                    Toggle(isOn: Binding(
                        get: { activityCenter.settings.hudMetricIDs.contains(metric.id) },
                        set: { isOn in
                            var ids = activityCenter.settings.hudMetricIDs
                            if isOn {
                                guard ids.count < AppSettings.maxHUDMetrics else { return }
                                ids.append(metric.id)
                            } else {
                                ids.removeAll { $0 == metric.id }
                            }
                            var s = activityCenter.settings
                            s.hudMetricIDs = ids
                            activityCenter.updateSettings(s)
                        }
                    )) {
                        HStack(spacing: 5) {
                            Image(systemName: metric.icon).foregroundStyle(.secondary)
                            Text(metric.title)
                        }
                    }
                }
                Text(L10n.t("settingsRootView.abc83896"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications

/// All notifications are opt-in and capped at one per day. The spec is explicit that Pawprint
/// must not pressure anyone, so there are no goal reminders or "you haven't used me" nudges —
/// only a recap of what already happened.
