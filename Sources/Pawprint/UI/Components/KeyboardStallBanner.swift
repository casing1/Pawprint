import AppKit
import SwiftUI
import PawprintCore

/// Warns that character keys are not being counted.
///
/// This failure has no other symptom. Every permission reads as granted, no counter sits at zero,
/// and the keyboard heatmap looks plausible until you notice it is made entirely of Shift, Command
/// and Return with not one letter on it. So it has to announce itself; nothing else will.
///
/// Shown in the popover as well as Settings, because the popover is where anyone would be looking
/// when they noticed the heatmap was wrong.
@MainActor
struct KeyboardStallBanner: View {
    @Bindable var permissions = PermissionsManager.shared
    /// The popover has no room for the full explanation.
    var compact = false

    var body: some View {
        if permissions.keyboardEventsStalled {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(L10n.t("permissions.keyboardStalled.title"))
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                    Spacer(minLength: 0)
                }
                Text(compact ? L10n.t("permissions.keyboardStalled.short")
                             : L10n.t("permissions.keyboardStalled.detail"))
                    .font(compact ? .system(size: 10) : .caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button(L10n.t("permissions.keyboardStalled.open")) {
                        permissions.openInputMonitoringSettings()
                    }
                    .controlSize(.small)
                    // Quitting is the reliable fix: re-registering the monitor is already
                    // attempted automatically, and if that had worked this banner would be gone.
                    Button(L10n.t("permissions.keyboardStalled.restart")) { NSApp.terminate(nil) }
                        .controlSize(.small)
                    Spacer(minLength: 0)
                }
            }
            .padding(compact ? 8 : 10)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.orange.opacity(0.13)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
        }
    }
}
