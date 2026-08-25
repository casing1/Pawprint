import SwiftUI
import AppKit
import PawprintCore

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
    @Environment(ActivityCenter.self) private var activityCenter
    @Bindable var achievements = AchievementEngine.shared
    @State private var tab: PopoverTab
    private let dismissPopover: () -> Void

    /// Capture only; the app itself always opens the gallery on rarity.
    static let gallerySort: PawpetGalleryView.SortField = {
        switch DebugEnvironment.gallerySort {
        case "date": return .date
        case "lustre": return .lustre
        case "score": return .score
        default: return .rarity
        }
    }()

    /// Pawprint's full category popover target is 406 × 640 points including AppKit chrome on the
    /// current macOS. This build's AppKit header adds 84 points around the scroll region.
    static let contentWidth: CGFloat = 380
    static let defaultScrollHeight: CGFloat = 556

    /// `var`, not `let`, only so the capture harness can shoot one tab at two different heights
    /// in a single run. Nothing in the app writes it.
    static var scrollHeight: CGFloat =
        DebugEnvironment.popoverHeight.flatMap { CGFloat(Double($0) ?? 0) }
            ?? defaultScrollHeight

    /// Capture only: opens the popover already scrolled to a named section.
    ///
    /// The Today tab is roughly twice the height of the tallest screenshot worth putting in a
    /// README, so the half below the fold — the fun facts and the keyboard heatmap — needs a shot
    /// of its own rather than a taller version of the first one. Anchored to a section rather than
    /// to the foot so the shot starts on a card boundary instead of halfway through one.
    static var shotScrollAnchor: String?

    /// The section the second Today screenshot starts from.
    static let funFactsAnchor = "pawprint.scroll.funfacts"

    /// Screenshot capture opens the popover directly on the tab it wants; everywhere else this
    /// defaults to Today exactly as before.
    init(
        startOn: PopoverTab = .today,
        dismissPopover: @escaping () -> Void = {}
    ) {
        _tab = State(initialValue: startOn)
        self.dismissPopover = dismissPopover
    }

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
            AnnouncementBanner()
                .padding(.horizontal, 12)
                .padding(.top, 10)
            KeyboardStallBanner(compact: true)
                .padding(.horizontal, 12)
                .padding(.top, 10)
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

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        switch tab {
                        case .today: TodayView()
                        case .calendar: CalendarView()
                        case .gallery:
                            PawpetGalleryView(
                                initialSort: PopoverRootView.gallerySort,
                                onOpenAdventureHUD: openAdventureHUD
                            )
                        case .records: RecordsView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    guard let anchor = Self.shotScrollAnchor else { return }
                    // A frame later: on the first pass the tab's own content has not been laid
                    // out yet, so there is nothing to scroll and the anchor is already on screen.
                    DispatchQueue.main.async { proxy.scrollTo(anchor, anchor: .top) }
                }
            }
            // Tall enough for the whole tab when capturing README screenshots: the popover is a
            // scrolling view, and a shot of its first 520 points leaves out the heatmap, the
            // activity clock and everything else below the fold.
            .frame(height: PopoverRootView.scrollHeight)
        }
        .frame(width: Self.contentWidth)
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
                openAdventureHUD()
            } label: {
                Image(systemName: "map.fill")
            }
            .buttonStyle(.plain)
            .help(L10n.t("adventure.expedition.hud.title"))

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

    private func openAdventureHUD() {
        let controller = AdventureExpeditionHUDController.shared
        if controller.isVisible {
            controller.hide()
        } else {
            dismissPopover()
            controller.show()
        }
    }
}

extension ActivityCenter {
    func updateSettings(withPaused isPaused: Bool) {
        var s = settings
        s.isPaused = isPaused
        updateSettings(s)
    }
}
