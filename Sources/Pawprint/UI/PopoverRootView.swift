import SwiftUI
import AppKit

enum PopoverTab: Int, CaseIterable {
    case today, calendar, gallery, records

    var label: String {
        switch self {
        case .today: return "오늘"
        case .calendar: return "활동 달력"
        case .gallery: return "도감"
        case .records: return "기록"
        }
    }
}

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
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar

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
            .help(activityCenter.settings.isPaused ? "기록 재개" : "기록 일시정지")

            Button {
                LiveHUDController.shared.toggle()
            } label: {
                Image(systemName: "rectangle.inset.filled.badge.record")
            }
            .buttonStyle(.plain)
            .help("라이브 세션 창 켜기/끄기")

            Button {
                SettingsOpener.open()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("설정")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Pawprint 종료")
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
