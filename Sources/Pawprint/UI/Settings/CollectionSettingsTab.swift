import SwiftUI
import PawprintCore

/// What Pawprint is allowed to record, and which applications it must never look at.
///
/// Every switch here is a promise: turning one off stops that category being recorded at all,
/// not merely hidden. The gate itself lives in `RecordingPolicy`.
@MainActor
struct CollectionSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        Form {
            Section {
                Toggle(L10n.t("settingsRootView.2cbbbd10"), isOn: activityCenter.binding(\.isPaused))
            }
            Section(L10n.t("settingsRootView.7f244382")) {
                Toggle(L10n.t("settingsRootView.573cc0a8"), isOn: activityCenter.binding(\.collectKeyboard))
                Toggle(L10n.t("settingsRootView.3a53938d"), isOn: activityCenter.binding(\.collectMouse))
                Toggle(L10n.t("settingsRootView.3dd1ec75"), isOn: activityCenter.binding(\.collectAppUsage))
                Toggle(L10n.t("settingsRootView.7c6e2e22"), isOn: activityCenter.binding(\.collectClipboard))
                Toggle(L10n.t("settingsRootView.bcafb5d0"), isOn: activityCenter.binding(\.collectSleepWake))
                Toggle(L10n.t("settingsRootView.d04beeae"), isOn: activityCenter.binding(\.collectPowerPeripherals))
            }

        }
        .formStyle(.grouped)
    }
}

// MARK: - Excluded apps

@MainActor
struct ExcludedAppsSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("settingsRootView.45523438"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding([.top, .horizontal])

            List {
                ForEach(activityCenter.settings.excludedApps) { app in
                    HStack {
                        Text(app.displayName)
                        Spacer()
                        Text(app.bundleID).font(.caption).foregroundStyle(.tertiary)
                        Button(role: .destructive) {
                            remove(app)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button(L10n.t("settingsRootView.3b94ada7")) { addApp() }
                    .padding([.horizontal, .bottom])
            }
        }
    }

    private func remove(_ app: ExcludedApp) {
        var s = activityCenter.settings
        s.excludedApps.removeAll { $0.id == app.id }
        activityCenter.updateSettings(s)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = L10n.t("settingsRootView.90015697")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        let name = (bundle.infoDictionary?["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
        var s = activityCenter.settings
        guard !s.excludedApps.contains(where: { $0.bundleID == bundleID }) else { return }
        s.excludedApps.append(ExcludedApp(bundleID: bundleID, displayName: name, isDefault: false))
        activityCenter.updateSettings(s)
    }
}

// MARK: - Live HUD
