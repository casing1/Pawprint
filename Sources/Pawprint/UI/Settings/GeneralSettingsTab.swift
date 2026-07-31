import SwiftUI
import PawprintCore

/// The General pane, and the two pickers that let the user choose what the Today tab and the
/// share card put in front of them.
@MainActor
struct GeneralSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            KeyboardStallBanner()
            Section {
                Toggle(L10n.t("settingsRootView.24530a7a"), isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        launchAtLoginEnabled = newValue
                        LaunchAtLogin.set(newValue)
                    }
                ))
                Toggle(L10n.t("settingsRootView.b9b55f4e"), isOn: activityCenter.binding(\.showDockIcon))
                Picker(L10n.t("settings.menuBarIcon"), selection: activityCenter.binding(\.menuBarIcon)) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        // The icon itself beside its name — the words "paw" and "cat" are a poor
                        // preview of something 17 points tall.
                        HStack(spacing: 6) {
                            Image(nsImage: MenuBarIconAnimator.previewImage(for: style))
                            Text(style.label)
                        }
                        .tag(style)
                    }
                }
                Picker(L10n.t("settingsRootView.76213e74"), selection: activityCenter.binding(\.menuBarMetric)) {
                    ForEach(MenuBarMetric.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker(L10n.t("settingsRootView.5d8fee11"), selection: activityCenter.binding(\.theme)) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker(L10n.t("settings.language"), selection: activityCenter.binding(\.language)) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Stepper(
                    L10n.t("settingsRootView.b9bbcb6a", activityCenter.settings.dayStartHour),
                    value: activityCenter.binding(\.dayStartHour),
                    in: 0...23
                )
            }

            // Deliberately a plain link, not an in-app action. Starring a repository is a public
            // act on someone's GitHub account, so it belongs to them: this opens the page and
            // they decide. Doing it on their behalf would need their credentials, and quietly
            // inflating stars is against GitHub's terms besides.
            Section {
                Link(destination: URL(string: "https://github.com/yhcho0405/Pawprint")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "star")
                        Text(L10n.t("settingsRootView.f1481e16"))
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Section(L10n.t("settingsRootView.4d02bde7")) {
                PermissionStatusRows()
                HStack {
                    Button(L10n.t("settingsRootView.9aa2b706")) { OnboardingWindowController.shared.present() }
                    Spacer()
                }
            }

            Section(L10n.t("settingsRootView.6db6c218", AppSettings.maxDashboardCards)) {
                DashboardCardPicker()
            }

            Section(L10n.t("settingsRootView.42a37112", AppSettings.maxShareCardMetrics)) {
                ShareCardMetricPicker()
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
struct DashboardCardPicker: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        // Driven entirely by `MetricCatalog`: a metric added there shows up here with no edit.
        ForEach(MetricCatalog.enabled(MetricCatalog.cardMetrics, settings: activityCenter.settings)) { metric in
            Toggle(isOn: Binding(
                get: { activityCenter.settings.dashboardCardIDs.contains(metric.id) },
                set: { isOn in
                    var ids = activityCenter.settings.dashboardCardIDs
                    if isOn {
                        guard ids.count < AppSettings.maxDashboardCards else { return }
                        ids.append(metric.id)
                    } else {
                        ids.removeAll { $0 == metric.id }
                    }
                    var s = activityCenter.settings
                    s.dashboardCardIDs = ids
                    activityCenter.updateSettings(s)
                }
            )) {
                HStack(spacing: 5) {
                    Image(systemName: metric.icon).foregroundStyle(.secondary)
                    Text(metric.title)
                    InfoBadge(title: metric.title, explanation: metric.explanation)
                }
            }
        }
    }
}

/// Same catalog-driven pattern as the dashboard picker — a metric added to `MetricCatalog`
/// becomes selectable for the share card with no edit here.
@MainActor
struct ShareCardMetricPicker: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        ForEach(MetricCatalog.enabled(MetricCatalog.all, settings: activityCenter.settings)) { metric in
            Toggle(isOn: Binding(
                get: { activityCenter.settings.shareCardMetricIDs.contains(metric.id) },
                set: { isOn in
                    var ids = activityCenter.settings.shareCardMetricIDs
                    if isOn {
                        guard ids.count < AppSettings.maxShareCardMetrics else { return }
                        ids.append(metric.id)
                    } else {
                        ids.removeAll { $0 == metric.id }
                    }
                    var s = activityCenter.settings
                    s.shareCardMetricIDs = ids
                    activityCenter.updateSettings(s)
                }
            )) {
                HStack(spacing: 5) {
                    Image(systemName: metric.icon).foregroundStyle(.secondary)
                    Text(metric.title)
                }
            }
        }
    }
}

// MARK: - Collection
