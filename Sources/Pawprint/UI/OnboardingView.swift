import AppKit
import SwiftUI
import UserNotifications

/// First-run setup.
///
/// Pawprint is dead on arrival without Accessibility and Input Monitoring — no keys, no clicks, no
/// app switches — but macOS grants neither silently, and its own prompts appear once and then never
/// again. Left to the status item alone, a new user sees a paw icon reporting zeros and no
/// explanation. This walks through each grant, polls until it actually lands, and says plainly what
/// each one is for.
///
/// Notifications and the login item are offered here too but never required: both are conveniences,
/// and the app works completely without them.
struct OnboardingView: View {
    @Bindable var permissions = PermissionsManager.shared
    @Bindable var activityCenter = ActivityCenter.shared

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var onFinish: () -> Void

    private var requiredGranted: Bool { permissions.allGranted }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView { checklist.padding(16) }

            Divider()
            footer
        }
        .frame(width: 460, height: 560)
        .onAppear {
            permissions.refresh()
            permissions.startPolling(interval: 1.0)
            Task { notificationStatus = await NotificationManager.shared.authorizationStatus() }
        }
        .onDisappear { permissions.stopPolling() }
    }

    // MARK: - Sections

    /// The scrollable middle, exposed rather than inlined so it can be rendered on its own:
    /// `ImageRenderer` produces an empty page for `ScrollView` contents, which would make any
    /// layout regression here invisible to snapshot checks.
    var checklist: some View {
            VStack(alignment: .leading, spacing: 14) {
                privacyNote

                Text("필수 권한").font(.caption).foregroundStyle(.secondary)

                step(
                    number: 1,
                    title: "손쉬운 사용",
                    detail: "마우스 이벤트와 앱 전환을 감지하는 데 필요해요.",
                    granted: permissions.accessibilityGranted,
                    primary: ("권한 요청", { permissions.requestAccessibility() }),
                    secondary: ("시스템 설정 열기", { permissions.openAccessibilitySettings() })
                )

                step(
                    number: 2,
                    title: "입력 모니터링",
                    detail: "키를 눌렀다는 사실만 감지해요. 무엇을 입력했는지는 읽지도, 저장하지도 않아요.",
                    granted: permissions.inputMonitoringGranted,
                    primary: ("권한 요청", { permissions.requestInputMonitoring() }),
                    secondary: ("시스템 설정 열기", { permissions.openInputMonitoringSettings() })
                )

                Text("선택 사항").font(.caption).foregroundStyle(.secondary).padding(.top, 4)

                optionalRow(
                    icon: "bell.badge",
                    title: "알림",
                    detail: notificationDetail,
                    isOn: notificationStatus == .authorized || notificationStatus == .provisional,
                    actionLabel: notificationStatus == .denied ? "시스템 설정 열기" : "허용하기",
                    action: handleNotifications
                )

                optionalRow(
                    icon: "power",
                    title: "로그인 시 자동 실행",
                    detail: "Mac을 켜면 Pawprint가 자동으로 시작돼요. 기록이 끊기지 않아요.",
                    isOn: launchAtLogin,
                    actionLabel: launchAtLogin ? "해제" : "켜기",
                    action: toggleLaunchAtLogin
                )
            }
    }


    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Pawprint에 오신 걸 환영해요").font(.title3.weight(.semibold))
                Text("Mac을 어떻게 쓰는지 조용히 기록하고, 하루가 끝나면 보여드릴게요.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("기록되지 않는 것", systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
            Text("입력한 글자와 순서, 비밀번호, 클립보드 내용, 화면 캡처, 창·문서·웹페이지 내용은 저장하지 않아요. 횟수와 시간만 기록하고, 모든 데이터는 이 Mac에만 남아요.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }

    private var footer: some View {
        HStack {
            if !requiredGranted {
                Text("권한을 켜면 자동으로 다음 단계로 넘어가요")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Button("나중에 하기") { onFinish() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(requiredGranted ? "시작하기" : "권한 없이 계속") { onFinish() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Rows

    private func step(
        number: Int,
        title: String,
        detail: String,
        granted: Bool,
        primary: (String, () -> Void),
        secondary: (String, () -> Void)
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(granted ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 24, height: 24)
                if granted {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.weight(.bold))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    HStack(spacing: 8) {
                        Button(primary.0, action: primary.1).controlSize(.small)
                        Button(secondary.0, action: secondary.1)
                            .controlSize(.small).buttonStyle(.link)
                    }
                    .padding(.top, 2)
                } else {
                    Text("허용됨").font(.caption2).foregroundStyle(.green)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(granted ? Color.green.opacity(0.08) : Color.secondary.opacity(0.08))
        )
    }

    private func optionalRow(
        icon: String,
        title: String,
        detail: String,
        isOn: Bool,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isOn ? Color.green : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(actionLabel, action: action).controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.3)))
    }

    private var notificationDetail: String {
        switch notificationStatus {
        case .authorized, .provisional: return "하루 요약과 신기록 알림을 받을 수 있어요."
        case .denied: return "거부되어 있어요. 시스템 설정에서 켤 수 있어요."
        default: return "하루 요약과 신기록을 알려드릴까요? 원하지 않으면 건너뛰어도 돼요."
        }
    }

    // MARK: - Actions

    private func handleNotifications() {
        if notificationStatus == .denied {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        Task {
            _ = await NotificationManager.shared.requestAuthorizationIfNeeded()
            notificationStatus = await NotificationManager.shared.authorizationStatus()
        }
    }

    private func toggleLaunchAtLogin() {
        let next = !launchAtLogin
        LaunchAtLogin.set(next)
        launchAtLogin = LaunchAtLogin.isEnabled
        var updated = activityCenter.settings
        updated.launchAtLogin = launchAtLogin
        activityCenter.updateSettings(updated)
        _ = next
    }
}

/// Hosts `OnboardingView` in its own window.
///
/// The app runs as an accessory (no Dock icon), which means a plain window would open behind
/// everything and never take focus. Same treatment as the settings window: switch to `.regular`
/// while it's up, back to `.accessory` when it closes.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    func present() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: OnboardingView { [weak self] in self?.finish() })
        let window = NSWindow(contentViewController: hosting)
        window.title = "Pawprint 설정 마법사"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        var settings = ActivityCenter.shared.settings
        settings.hasCompletedOnboarding = true
        ActivityCenter.shared.updateSettings(settings)
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Mark it done even on a plain close, so it doesn't reappear on every launch.
        var settings = ActivityCenter.shared.settings
        if !settings.hasCompletedOnboarding {
            settings.hasCompletedOnboarding = true
            ActivityCenter.shared.updateSettings(settings)
        }
        if !ActivityCenter.shared.settings.showDockIcon {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
