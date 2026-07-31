import AppKit
import SwiftUI
import UserNotifications
import PawprintCore

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
@MainActor
struct OnboardingView: View {
    @Bindable var permissions = PermissionsManager.shared
    @Environment(ActivityCenter.self) private var activityCenter

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

                Text(L10n.t("onboardingView.d788f1b9")).font(.caption).foregroundStyle(.secondary)

                step(
                    number: 1,
                    title: L10n.t("onboardingView.2008ca0e"),
                    detail: L10n.t("onboardingView.3caa40c7"),
                    granted: permissions.accessibilityGranted,
                    primary: (L10n.t("onboardingView.9076c0e6"), { permissions.requestAccessibility() }),
                    secondary: (L10n.t("onboardingView.a53aa7ea"), { permissions.openAccessibilitySettings() })
                )

                step(
                    number: 2,
                    title: L10n.t("onboardingView.e87e0ec4"),
                    detail: L10n.t("onboardingView.b800f998"),
                    granted: permissions.inputMonitoringGranted,
                    primary: (L10n.t("onboardingView.9076c0e6"), { permissions.requestInputMonitoring() }),
                    secondary: (L10n.t("onboardingView.a53aa7ea"), { permissions.openInputMonitoringSettings() })
                )

                Text(L10n.t("onboardingView.3259d0ae")).font(.caption).foregroundStyle(.secondary).padding(.top, 4)

                optionalRow(
                    icon: "bell.badge",
                    title: L10n.t("onboardingView.e29d147e"),
                    detail: notificationDetail,
                    isOn: notificationStatus == .authorized || notificationStatus == .provisional,
                    actionLabel: notificationStatus == .denied ? L10n.t("onboardingView.a53aa7ea") : L10n.t("onboardingView.2be27d6a"),
                    action: handleNotifications
                )

                optionalRow(
                    icon: "power",
                    title: L10n.t("onboardingView.24530a7a"),
                    detail: L10n.t("onboardingView.d17086d3"),
                    isOn: launchAtLogin,
                    actionLabel: launchAtLogin ? L10n.t("onboardingView.a7abea5b") : L10n.t("onboardingView.a57a2d9a"),
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
                Text(L10n.t("onboardingView.3e9c7a4b")).font(.title3.weight(.semibold))
                Text(L10n.t("onboardingView.c0bf9d1b"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(L10n.t("onboardingView.e4cb0796"), systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
            Text(L10n.t("onboardingView.51bbb9bc"))
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("onboardingView.f5179fab"))
                .font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }

    private var footer: some View {
        HStack {
            if !requiredGranted {
                Text(L10n.t("onboardingView.668011ac"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Button(L10n.t("onboardingView.c9c8403d")) { onFinish() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(requiredGranted ? L10n.t("onboardingView.389b82de") : L10n.t("onboardingView.9e7ad479")) { onFinish() }
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
                    Text(L10n.t("onboardingView.a157c8c4")).font(.caption2).foregroundStyle(.green)
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
        case .authorized, .provisional: return L10n.t("onboardingView.0e30212e")
        case .denied: return L10n.t("onboardingView.0e562213")
        default: return L10n.t("onboardingView.ed23b382")
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

        let hosting = NSHostingController(rootView: OnboardingView { [weak self] in self?.finish() }
            .pawprintEnvironment())
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t("onboardingView.19668f3a")
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
