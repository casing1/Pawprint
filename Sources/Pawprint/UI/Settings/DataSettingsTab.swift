import SwiftUI
import PawprintCore

/// Export, retention and deletion.
///
/// The end of the promise the app makes: everything is local, and all of it can be taken away
/// in one click. `PermissionStatusRows` sits here because what has been granted is part of the
/// same question as what has been kept.
@MainActor
struct DataSettingsTab: View {
    @Environment(ActivityCenter.self) private var activityCenter
    @State private var deleteDate = Date()
    @State private var showDeleteAllConfirm = false
    @State private var showDeleteDateConfirm = false
    @State private var exportMessage: String?

    var body: some View {
        Form {
            Section(L10n.t("settingsRootView.f130a33e")) {
                Picker(L10n.t("settingsRootView.c4d8f13d"), selection: activityCenter.binding(\.retentionDays)) {
                    Text(L10n.t("settingsRootView.504b4b63")).tag(30)
                    Text(L10n.t("settingsRootView.f5c43d03")).tag(90)
                    Text(L10n.t("settingsRootView.e8680014")).tag(180)
                    Text(L10n.t("settingsRootView.fa41cf32")).tag(365)
                    Text(L10n.t("settingsRootView.de824e4f")).tag(0)
                }
                Text(L10n.t("settingsRootView.ee0ecd1a", PawprintStore.shared.databaseURL.path))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Section(L10n.t("settingsRootView.c3a6ac35")) {
                Button(L10n.t("settingsRootView.c80acff1")) { exportCSV() }
                Button(L10n.t("settingsRootView.6abc1f94")) { exportData() }
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(L10n.t("settingsRootView.fc81e222")) {
                DatePicker(L10n.t("settingsRootView.9cfd39c5"), selection: $deleteDate, displayedComponents: .date)
                Button(L10n.t("settingsRootView.57ee6700"), role: .destructive) { showDeleteDateConfirm = true }
                    .confirmationDialog(L10n.t("settingsRootView.20d7b731"), isPresented: $showDeleteDateConfirm, titleVisibility: .visible) {
                        Button(L10n.t("settingsRootView.fc81e222"), role: .destructive) { deleteDate(deleteDate) }
                        Button(L10n.t("settingsRootView.19b2d19b"), role: .cancel) {}
                    }

                Button(L10n.t("settingsRootView.90e1a615"), role: .destructive) { showDeleteAllConfirm = true }
                    .confirmationDialog(L10n.t("settingsRootView.ca6259e9"), isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
                        Button(L10n.t("settingsRootView.dfa74759"), role: .destructive) { deleteAll(includingAchievements: false) }
                        Button(L10n.t("settingsRootView.da1d4a83"), role: .destructive) { deleteAll(includingAchievements: true) }
                        Button(L10n.t("settingsRootView.19b2d19b"), role: .cancel) {}
                    }
            }
        }
        .formStyle(.grouped)
    }

    /// CSV is the format people actually chart; JSON stays available for a full fidelity backup.
    private func exportCSV() {
        guard let data = PawprintStore.shared.exportAllAsCSV(dayStartHour: activityCenter.settings.dayStartHour) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "pawprint_export.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            exportMessage = L10n.t("settingsRootView.dbcfd145", url.lastPathComponent)
        } catch {
            exportMessage = L10n.t("settingsRootView.a2f75add", error.localizedDescription)
        }
    }

    private func exportData() {
        guard let data = PawprintStore.shared.exportAllAsJSON() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "pawprint_export.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            exportMessage = L10n.t("settingsRootView.f17ca062", url.lastPathComponent)
        } catch {
            exportMessage = L10n.t("settingsRootView.a2f75add", error.localizedDescription)
        }
    }

    private func deleteDate(_ date: Date) {
        let key = DayKey.string(for: date, dayStartHour: activityCenter.settings.dayStartHour)
        PawprintStore.shared.deleteDay(key)
        SummaryCache.shared.invalidate(key)
        activityCenter.reloadToday()
    }

    private func deleteAll(includingAchievements: Bool) {
        PawprintStore.shared.deleteAll()
        if includingAchievements {
            AchievementEngine.shared.resetAll()
        }
        activityCenter.reloadToday()
    }
}


// MARK: - Permissions

/// Live status of the two grants the app can't work without. Shown in Settings as well as the
/// wizard because macOS lets a user revoke them at any time, and the failure mode — every counter
/// silently stuck at zero — gives no hint about why.
@MainActor
struct PermissionStatusRows: View {
    @Bindable var permissions = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(L10n.t("settingsRootView.2008ca0e"), permissions.accessibilityGranted) { permissions.openAccessibilitySettings() }
            row(L10n.t("settingsRootView.e87e0ec4"), permissions.inputMonitoringGranted) { permissions.openInputMonitoringSettings() }

        }
        .onAppear { permissions.refresh() }
    }

    private func row(_ title: String, _ granted: Bool, _ open: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            if granted {
                Text(L10n.t("settingsRootView.a157c8c4")).font(.caption).foregroundStyle(.secondary)
            } else {
                Button(L10n.t("settingsRootView.e5637183"), action: open).controlSize(.small)
            }
        }
    }
}

// MARK: - Updates

/// Pawprint is distributed outside the App Store, so it has to look after its own updates.
/// The check is a network request, which this app otherwise never makes — hence the explicit
/// opt-in and the plain description of exactly what gets sent.
