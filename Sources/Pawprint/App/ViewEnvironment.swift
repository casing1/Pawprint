import SwiftUI
import PawprintCore

/// How the views get hold of the application's objects.
///
/// They used to reach for `.shared` directly — `@Bindable var activityCenter = ActivityCenter.shared`
/// at the top of eleven view files. That is what made a view impossible to look at on its own: a
/// preview, a screenshot or a test of `TodayView` stood up the real activity centre, which opened
/// the real database in Application Support and started the real timers.
///
/// The objects are injected at the root instead and read back out of the environment. For
/// `ActivityCenter` this is SwiftUI's own Observation-based environment, which is exactly what it
/// is for; the store needs a key of its own because it is not `@Observable`.
private struct StoreKey: EnvironmentKey {
    static let defaultValue: any ActivityStore = PawprintStore.shared
}

extension EnvironmentValues {
    /// Where days come from. A view that reads history takes this rather than naming SQLite.
    var store: any ActivityStore {
        get { self[StoreKey.self] }
        set { self[StoreKey.self] = newValue }
    }
}

extension View {
    /// Injects everything the view tree needs. Applied once, at each window's root.
    ///
    /// One call rather than three modifiers per window, so a new dependency is added in one place
    /// and cannot be forgotten at one of the four roots — the popover, the settings window, the
    /// onboarding window and the HUD.
    @MainActor
    func pawprintEnvironment(_ environment: AppEnvironment = .live) -> some View {
        self
            .environment(environment.activityCenter)
            .environment(\.store, environment.store)
    }
}
