import SwiftUI
import AppKit
import UserNotifications

@MainActor
struct SettingsRootView: View {
    @Bindable var activityCenter = ActivityCenter.shared

    private var colorScheme: ColorScheme? {
        switch activityCenter.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.aef1a1e7"), systemImage: "gearshape") }
            CollectionSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.c5b9a11e"), systemImage: "chart.bar") }
            ExcludedAppsSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.48511ffb"), systemImage: "nosign") }
            HUDSettingsTab()
                .tabItem { Label("HUD", systemImage: "rectangle.inset.filled") }
            NotificationSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.e29d147e"), systemImage: "bell") }
            DataSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.0c6de345"), systemImage: "externaldrive") }
            UpdateSettingsTab()
                .tabItem { Label(L10n.t("settingsRootView.4f72dd68"), systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 460, height: 420)
        .id(LocalizationManager.shared.revision)
        .preferredColorScheme(colorScheme)
    }
}

// MARK: - General

@MainActor
private struct GeneralSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle(L10n.t("settingsRootView.24530a7a"), isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        launchAtLoginEnabled = newValue
                        LaunchAtLogin.set(newValue)
                    }
                ))
                Toggle(L10n.t("settingsRootView.b9b55f4e"), isOn: activityCenter.binding(\.showDockIcon))
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
private struct DashboardCardPicker: View {
    @Bindable var activityCenter = ActivityCenter.shared

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
private struct ShareCardMetricPicker: View {
    @Bindable var activityCenter = ActivityCenter.shared

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

@MainActor
private struct CollectionSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared

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
            Section(L10n.t("settingsRootView.5cabef7f")) {
                Stepper(
                    L10n.t("settingsRootView.59af7816", activityCenter.settings.focusThresholdSeconds / 60),
                    value: Binding(
                        get: { activityCenter.settings.focusThresholdSeconds / 60 },
                        set: { minutes in
                            var s = activityCenter.settings
                            s.focusThresholdSeconds = minutes * 60
                            activityCenter.updateSettings(s)
                        }
                    ),
                    in: 1...60
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Excluded apps

@MainActor
private struct ExcludedAppsSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared

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

@MainActor
private struct HUDSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared

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
                Text(L10n.t("settingsRootView.ae73ebc3"))
                    .font(.caption2).foregroundStyle(.tertiary)
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
@MainActor
private struct NotificationSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared
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

@MainActor
private struct DataSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared
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
private struct PermissionStatusRows: View {
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
@MainActor
private struct UpdateSettingsTab: View {
    @Bindable var activityCenter = ActivityCenter.shared
    @Bindable var updater = UpdateChecker.shared

    private var settings: AppSettings { activityCenter.settings }

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.t("settingsRootView.c0a56eea")) {
                    Text("\(updater.currentVersion) (\(updater.currentBuild))")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(L10n.t("settingsRootView.ef2792c1"), isOn: activityCenter.binding(\.updateCheckEnabled))
                Text(L10n.t("settingsRootView.267a3303"))
                    .font(.caption2).foregroundStyle(.secondary)

                if settings.updateCheckEnabled {
                    Toggle(L10n.t("settingsRootView.aa2a685b"), isOn: activityCenter.binding(\.updateCheckAutomatically))
                    TextField(L10n.t("settingsRootView.b644dd89"),
                              text: activityCenter.binding(\.updateFeedURL))
                        .textFieldStyle(.roundedBorder)
                }
            }

            if settings.updateCheckEnabled {
                Section(L10n.t("settingsRootView.2926977b")) {
                    statusRow
                    HStack {
                        Button(L10n.t("settingsRootView.a8201e37")) {
                            Task { await updater.check(feedURL: settings.updateFeedURL, manual: true) }
                        }
                        .disabled(settings.updateFeedURL.isEmpty || isBusy)
                        if case .available(let release) = updater.state {
                            Button(L10n.t("settingsRootView.5c5095ab")) { Task { await updater.download(release) } }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.t("settingsRootView.7d536052")) { updater.openDownloadPage(release) }
                        }
                        if case .readyToInstall = updater.state {
                            Button(L10n.t("settingsRootView.e723d26a")) { updater.install() }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.t("settingsRootView.19b2d19b")) { updater.dismiss() }
                        }
                        Spacer()
                    }
                }
            }

            Section(L10n.t("settingsRootView.7d793248")) {
                Text(L10n.t("settingsRootView.bf7fbbb3"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var isBusy: Bool {
        switch updater.state {
        case .checking, .downloading: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle:
            Text(L10n.t("settingsRootView.b0177d91")).font(.caption).foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(L10n.t("settingsRootView.33c1f78f")).font(.caption) }
        case .upToDate(let at):
            Label(L10n.t("settingsRootView.964c983e", at.formatted(date: .omitted, time: .shortened)),
                  systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .available(let release):
            VStack(alignment: .leading, spacing: 3) {
                Label(L10n.t("settingsRootView.dbaf68c1", release.version), systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                if let notes = release.notes {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("settingsRootView.cc336a93")).font(.caption)
                ProgressView(value: progress)
            }
        case .readyToInstall(let release):
            Label(L10n.t("settingsRootView.64b5f1e0", release.version), systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
