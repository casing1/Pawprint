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
                .tabItem { Label("일반", systemImage: "gearshape") }
            CollectionSettingsTab()
                .tabItem { Label("수집", systemImage: "chart.bar") }
            ExcludedAppsSettingsTab()
                .tabItem { Label("제외 앱", systemImage: "nosign") }
            HUDSettingsTab()
                .tabItem { Label("HUD", systemImage: "rectangle.inset.filled") }
            NotificationSettingsTab()
                .tabItem { Label("알림", systemImage: "bell") }
            DataSettingsTab()
                .tabItem { Label("데이터", systemImage: "externaldrive") }
            UpdateSettingsTab()
                .tabItem { Label("업데이트", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 460, height: 420)
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
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        launchAtLoginEnabled = newValue
                        LaunchAtLogin.set(newValue)
                    }
                ))
                Toggle("Dock 아이콘 표시", isOn: activityCenter.binding(\.showDockIcon))
                Picker("메뉴바 대표 지표", selection: activityCenter.binding(\.menuBarMetric)) {
                    ForEach(MenuBarMetric.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("테마", selection: activityCenter.binding(\.theme)) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Stepper(
                    "하루 시작 시각: \(activityCenter.settings.dayStartHour)시",
                    value: activityCenter.binding(\.dayStartHour),
                    in: 0...23
                )
            }

            Section("권한") {
                PermissionStatusRows()
                HStack {
                    Button("설정 마법사 다시 열기") { OnboardingWindowController.shared.present() }
                    Spacer()
                }
            }

            Section("오늘 탭 대표 카드 (최대 \(AppSettings.maxDashboardCards)개)") {
                DashboardCardPicker()
            }

            Section("공유 카드에 넣을 항목 (최대 \(AppSettings.maxShareCardMetrics)개)") {
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
                Toggle("전체 기록 일시정지", isOn: activityCenter.binding(\.isPaused))
            }
            Section("수집 카테고리") {
                Toggle("키보드 통계", isOn: activityCenter.binding(\.collectKeyboard))
                Toggle("마우스 통계", isOn: activityCenter.binding(\.collectMouse))
                Toggle("앱 사용시간", isOn: activityCenter.binding(\.collectAppUsage))
                Toggle("클립보드 횟수", isOn: activityCenter.binding(\.collectClipboard))
                Toggle("잠자기·깨우기", isOn: activityCenter.binding(\.collectSleepWake))
                Toggle("전원과 주변장치", isOn: activityCenter.binding(\.collectPowerPeripherals))
            }
            Section("집중 세션 기준") {
                Stepper(
                    "\(activityCenter.settings.focusThresholdSeconds / 60)분 이상 유지 시 집중 세션으로 인정",
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
            Text("이 앱들에서는 기록이 자동으로 중단됩니다.")
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
                Button("앱 추가…") { addApp() }
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
        panel.prompt = "제외 목록에 추가"
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
                    Button(LiveHUDController.shared.isVisible ? "HUD 숨기기" : "HUD 표시")
                        { LiveHUDController.shared.toggle() }
                    Spacer()
                }
                Toggle("축소 모드", isOn: Binding(
                    get: { activityCenter.settings.hudCompact },
                    set: { activityCenter.setHUDCompact($0) }
                ))
                Text("투명도는 HUD 상단의 반원 버튼에서 조절해요 — 뒤에 깔린 화면을 보면서 맞춰야 하니까요.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Section("현재 세션 항목") {
                Toggle("세션 시간", isOn: activityCenter.binding(\.hudShowsSessionTime))
                Toggle("이번 세션 키", isOn: activityCenter.binding(\.hudShowsSessionKeys))
                Toggle("이번 세션 클릭", isOn: activityCenter.binding(\.hudShowsSessionClicks))
            }

            Section("오늘 통계 항목 (최대 \(AppSettings.maxHUDMetrics)개)") {
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
                Text("축소 모드에서는 WPM과 세션 시간만 표시돼요.")
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
            Section("하루 요약") {
                Toggle("매일 요약 알림 받기", isOn: Binding(
                    get: { activityCenter.settings.dailySummaryEnabled },
                    set: { isOn in
                        var s = activityCenter.settings
                        s.dailySummaryEnabled = isOn
                        activityCenter.updateSettings(s)
                        Task { await apply(enabled: isOn) }
                    }
                ))
                DatePicker("알림 시각", selection: summaryTime, displayedComponents: .hourAndMinute)
                    .disabled(!activityCenter.settings.dailySummaryEnabled)
                Text("그날의 등급, 사용시간, 키 입력을 한 줄로 알려줘요. 소리는 울리지 않아요.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Section("업적 알림") {
                Toggle("레벨업 알림", isOn: Binding(
                    get: { activityCenter.settings.celebrationNotificationsEnabled },
                    set: { isOn in
                        var s = activityCenter.settings
                        s.celebrationNotificationsEnabled = isOn
                        activityCenter.updateSettings(s)
                        if isOn { Task { _ = await NotificationManager.shared.requestAuthorizationIfNeeded() } }
                    }
                ))
                Text("퀘스트 트랙이 레벨업했을 때만, 하루 최대 \(AppSettings.maxAchievementNotificationsPerDay)번까지 울려요. 개인 기록 갱신은 알림 없이 앱 안에서만 축하해요 — 누적 지표라 하루에도 여러 번 넘어서거든요.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Section("알림 권한") {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                    Text(statusText).font(.callout)
                    Spacer()
                }
                HStack {
                    Button("권한 확인") { Task { await refreshStatus() } }
                    Button("시스템 설정 열기") { openNotificationSettings() }
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
        case .authorized: return "알림이 허용되어 있어요"
        case .provisional: return "조용한 알림으로 허용되어 있어요"
        case .denied: return "알림이 거부되어 있어요 — 시스템 설정에서 켜주세요"
        case .notDetermined: return "아직 권한을 요청하지 않았어요"
        @unknown default: return "권한 상태를 확인할 수 없어요"
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
            authorizationNote = "시스템 설정 > 알림에서 Pawprint의 알림을 허용해 주세요."
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
            Section("보존 기간") {
                Picker("보관 기간", selection: activityCenter.binding(\.retentionDays)) {
                    Text("30일").tag(30)
                    Text("90일").tag(90)
                    Text("180일").tag(180)
                    Text("365일").tag(365)
                    Text("영구 보관").tag(0)
                }
                Text("데이터 위치: \(PawprintStore.shared.databaseURL.path)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Section("내보내기") {
                Button("모든 기록을 CSV로 내보내기…") { exportCSV() }
                Button("모든 기록을 JSON으로 내보내기…") { exportData() }
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("삭제") {
                DatePicker("특정 날짜 삭제", selection: $deleteDate, displayedComponents: .date)
                Button("이 날짜 기록 삭제", role: .destructive) { showDeleteDateConfirm = true }
                    .confirmationDialog("이 날짜의 기록을 삭제할까요?", isPresented: $showDeleteDateConfirm, titleVisibility: .visible) {
                        Button("삭제", role: .destructive) { deleteDate(deleteDate) }
                        Button("취소", role: .cancel) {}
                    }

                Button("전체 기록 완전 삭제", role: .destructive) { showDeleteAllConfirm = true }
                    .confirmationDialog("모든 Pawprint 기록을 완전히 삭제할까요? 이 작업은 되돌릴 수 없습니다.", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
                        Button("전체 삭제 (업적 유지)", role: .destructive) { deleteAll(includingAchievements: false) }
                        Button("전체 삭제 + 업적까지 초기화", role: .destructive) { deleteAll(includingAchievements: true) }
                        Button("취소", role: .cancel) {}
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
            exportMessage = "CSV 내보내기 완료: \(url.lastPathComponent)"
        } catch {
            exportMessage = "내보내기 실패: \(error.localizedDescription)"
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
            exportMessage = "내보내기 완료: \(url.lastPathComponent)"
        } catch {
            exportMessage = "내보내기 실패: \(error.localizedDescription)"
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
            row("손쉬운 사용", permissions.accessibilityGranted) { permissions.openAccessibilitySettings() }
            row("입력 모니터링", permissions.inputMonitoringGranted) { permissions.openInputMonitoringSettings() }
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
                Text("허용됨").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("열기", action: open).controlSize(.small)
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
                LabeledContent("현재 버전") {
                    Text("\(updater.currentVersion) (\(updater.currentBuild))")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("업데이트 확인 사용", isOn: activityCenter.binding(\.updateCheckEnabled))
                Text("Pawprint가 인터넷에 접속하는 유일한 기능이에요. 켜면 아래 주소로 GET 요청 한 번을 보내고, 기기 정보나 사용 기록은 아무것도 함께 보내지 않아요. 꺼두면 앱은 완전히 오프라인으로 동작해요.")
                    .font(.caption2).foregroundStyle(.secondary)

                if settings.updateCheckEnabled {
                    Toggle("실행할 때 자동으로 확인", isOn: activityCenter.binding(\.updateCheckAutomatically))
                    TextField("업데이트 주소 (https://…/appcast.json)",
                              text: activityCenter.binding(\.updateFeedURL))
                        .textFieldStyle(.roundedBorder)
                }
            }

            if settings.updateCheckEnabled {
                Section("상태") {
                    statusRow
                    HStack {
                        Button("지금 확인") {
                            Task { await updater.check(feedURL: settings.updateFeedURL, manual: true) }
                        }
                        .disabled(settings.updateFeedURL.isEmpty || isBusy)
                        if case .available(let release) = updater.state {
                            Button("다운로드") { Task { await updater.download(release) } }
                                .buttonStyle(.borderedProminent)
                            Button("브라우저로 열기") { updater.openDownloadPage(release) }
                        }
                        if case .readyToInstall = updater.state {
                            Button("설치하고 재시작") { updater.install() }
                                .buttonStyle(.borderedProminent)
                            Button("취소") { updater.dismiss() }
                        }
                        Spacer()
                    }
                }
            }

            Section("서명 확인") {
                Text("내려받은 앱이 지금 실행 중인 앱과 같은 서명인지 확인한 뒤에만 교체해요. 서명이 다르면 설치를 중단해요 — 업데이트 주소가 바뀌어도 임의의 코드가 실행되지 않도록.")
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
            Text("아직 확인하지 않았어요").font(.caption).foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("확인 중…").font(.caption) }
        case .upToDate(let at):
            Label("최신 버전이에요 (\(at.formatted(date: .omitted, time: .shortened)) 확인)",
                  systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .available(let release):
            VStack(alignment: .leading, spacing: 3) {
                Label("새 버전 \(release.version)이 있어요", systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                if let notes = release.notes {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("내려받는 중…").font(.caption)
                ProgressView(value: progress)
            }
        case .readyToInstall(let release):
            Label("\(release.version) 설치 준비 완료 — 서명 확인됨", systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
