import SwiftUI
import AppKit
import UserNotifications
import PawprintCore

/// Which pane is showing. Held in `@State` on the root, which is the fix for a long-standing
/// annoyance: `TabView` kept its selection internally, so every settings change re-evaluated the
/// root body, rebuilt the `TabView`, and threw the user back to General mid-toggle.
private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, collection, excluded, hud, notifications, data, updates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return L10n.t("settingsRootView.aef1a1e7")
        case .collection: return L10n.t("settingsRootView.c5b9a11e")
        case .excluded: return L10n.t("settingsRootView.48511ffb")
        case .hud: return "HUD"
        case .notifications: return L10n.t("settingsRootView.e29d147e")
        case .data: return L10n.t("settingsRootView.0c6de345")
        case .updates: return L10n.t("settingsRootView.4f72dd68")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .collection: return "chart.bar"
        case .excluded: return "nosign"
        case .hud: return "rectangle.inset.filled"
        case .notifications: return "bell"
        case .data: return "externaldrive"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }
}

@MainActor
struct SettingsRootView: View {
    @Environment(ActivityCenter.self) private var activityCenter
    @State private var tab: SettingsTab

    /// Verification only: lets a probe open straight onto a non-General pane, so the "settings
    /// change knocks you back to General" regression can be reproduced without a pointer.
    init(startOn: String? = nil) {
        _tab = State(initialValue: SettingsTab(rawValue: startOn ?? "") ?? .general)
    }

    private var colorScheme: ColorScheme? {
        switch activityCenter.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// A hand-drawn bar rather than SwiftUI's `TabView`.
    ///
    /// `TabView` bridges to `NSTabView`, and that brought two problems nothing above it could fix:
    /// its selection lived inside AppKit, so any rebuild of this body reset it to the first tab;
    /// and it draws its own full-width tab-strip background behind the pills, which read as a
    /// stray panel sitting under the labels with no margin above or below.
    var body: some View {
        // Read once so the labels below re-evaluate when the language changes. `L10n.t` is a plain
        // dictionary read and creates no dependency of its own.
        let revision = LocalizationManager.shared.revision

        return VStack(spacing: 0) {
            tabBar
            Divider()
            pane
                .id(revision)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Seven tabs need the room: at 460 the labels were squeezed into each other, and the
        // longer English ones dropped out entirely.
        .frame(width: 620, height: 480)
        .preferredColorScheme(colorScheme)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon).font(.system(size: 14))
                        Text(item.label).font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tab == item ? Color.accentColor.opacity(0.18) : .clear))
                    .foregroundStyle(tab == item ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var pane: some View {
        switch tab {
        case .general: GeneralSettingsTab()
        case .collection: CollectionSettingsTab()
        case .excluded: ExcludedAppsSettingsTab()
        case .hud: HUDSettingsTab()
        case .notifications: NotificationSettingsTab()
        case .data: DataSettingsTab()
        case .updates: UpdateSettingsTab()
        }
    }
}

// MARK: - General
