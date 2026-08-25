import AppKit
import SwiftUI
import PawprintCore

/// Shown before any permission request. Per the spec's privacy principle #8 ("권한 요청 전,
/// 무엇을 수집하지 않는지 먼저 설명한다") — explains what Pawprint never touches *before*
/// asking for Accessibility / Input Monitoring access.
@MainActor
struct PermissionOnboardingView: View {
    @Bindable var permissions = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("🐾").font(.system(size: 28))
                Text(L10n.t("permissionOnboardingView.d85887e6"))
                    .font(.title3.weight(.semibold))
            }

            Text(L10n.t("permissionOnboardingView.097948e3"))
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                bullet(L10n.t("permissionOnboardingView.7b1cdfc5"))
                bullet(L10n.t("permissionOnboardingView.ab8415b2"))
                bullet(L10n.t("permissionOnboardingView.fffec09f"))
                bullet(L10n.t("permissionOnboardingView.d4b1a626"))
                bullet(L10n.t("permissionOnboardingView.5d13df42"))
            }
            .font(.callout)

            Divider()

            Text(L10n.t("permissionOnboardingView.c8f6f079"))
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                permissionRow(
                    title: L10n.t("permissionOnboardingView.5a9be03f"),
                    granted: permissions.accessibilityGranted,
                    request: { permissions.requestAccessibility() },
                    openSettings: { permissions.openAccessibilitySettings() }
                )
                permissionRow(
                    title: L10n.t("permissionOnboardingView.8f73ee5e"),
                    granted: permissions.inputMonitoringGranted,
                    request: { permissions.requestInputMonitoring() },
                    openSettings: { permissions.openInputMonitoringSettings() }
                )
            }
            .padding(.top, 4)

            Text(L10n.t("permissionOnboardingView.a2138d5f"))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Button(L10n.t("permissionOnboardingView.5850b463")) { permissions.refresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button(L10n.t("permissionOnboardingView.e3bc5d45")) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Text(L10n.t("permissionOnboardingView.5f964e3f"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 360)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.green)
                .font(.caption)
                .padding(.top, 2)
            Text(text)
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, request: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(title)
                .font(.callout)
            Spacer()
            if !granted {
                Button(L10n.t("permissionOnboardingView.2be27d6a")) {
                    request()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

/// Presents the permission-only onboarding UI when a development build has lost its TCC grants.
///
/// This is deliberately separate from `OnboardingWindowController`: closing a repair window must
/// not rewrite first-run state, and the user should land directly on the two controls that need
/// attention rather than replaying the entire welcome flow.
@MainActor
final class PermissionRepairWindowController: NSObject, NSWindowDelegate {
    static let shared = PermissionRepairWindowController()

    private var window: NSWindow?

    func present() {
        if let window {
            bringToFront(window)
            return
        }

        let hosting = NSHostingController(rootView: PermissionOnboardingView())
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t("permissionOnboardingView.d85887e6")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        window.delegate = self
        self.window = window

        bringToFront(window)
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AppWindowActivationPolicy.restore(afterClosing: notification)
    }
}
