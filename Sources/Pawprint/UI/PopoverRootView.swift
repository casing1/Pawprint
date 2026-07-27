import SwiftUI
import AppKit

enum PopoverTab: Int, CaseIterable {
    case today, calendar, gallery, records

    var label: String {
        switch self {
        case .today: return L10n.t("popoverRootView.2bdce5e8")
        case .calendar: return L10n.t("popoverRootView.7b98812d")
        case .gallery: return L10n.t("popoverRootView.7d776781")
        case .records: return L10n.t("popoverRootView.d84b6f4b")
        }
    }
}

@MainActor
struct PopoverRootView: View {
    @Bindable var permissions = PermissionsManager.shared
    @Bindable var activityCenter = ActivityCenter.shared
    @Bindable var achievements = AchievementEngine.shared
    @State private var tab: PopoverTab = .today

    private var colorScheme: ColorScheme? {
        switch activityCenter.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        Group {
            if !permissions.allGranted {
                PermissionOnboardingView()
            } else {
                mainContent
            }
        }
        .onAppear {
            permissions.refresh()
            // Resumes polling if a permission was revoked while polling was stopped.
            permissions.startPolling()
        }
        .preferredColorScheme(colorScheme)
        .id(LocalizationManager.shared.revision)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar

            // Above the tabs so it is visible whichever tab was last open.
            UpdateBanner()
                .padding(.horizontal, 14)
                .padding(.top, 8)

            if let celebration = achievements.pendingCelebration {
                AchievementCelebrationBanner(id: celebration) {
                    withAnimation { achievements.clearCelebration() }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Picker("", selection: $tab) {
                ForEach(PopoverTab.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ScrollView {
                Group {
                    switch tab {
                    case .today: TodayView()
                    case .calendar: CalendarView()
                    case .gallery: PawpetGalleryView()
                    case .records: RecordsView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 520)
        }
        .frame(width: 380)
    }

    private var topBar: some View {
        HStack {
            Text("Pawprint")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                activityCenter.updateSettings(withPaused: !activityCenter.settings.isPaused)
            } label: {
                Image(systemName: activityCenter.settings.isPaused ? "play.circle" : "pause.circle")
            }
            .buttonStyle(.plain)
            .help(activityCenter.settings.isPaused ? L10n.t("popoverRootView.6491e6a9") : L10n.t("popoverRootView.5a694dfb"))

            Button {
                LiveHUDController.shared.toggle()
            } label: {
                Image(systemName: "rectangle.inset.filled.badge.record")
            }
            .buttonStyle(.plain)
            .help(L10n.t("popoverRootView.e6bbfa53"))

            Button {
                SettingsOpener.open()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help(L10n.t("popoverRootView.c14a567e"))

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help(L10n.t("popoverRootView.e3bc5d45"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
}

extension ActivityCenter {
    func updateSettings(withPaused isPaused: Bool) {
        var s = settings
        s.isPaused = isPaused
        updateSettings(s)
    }
}
