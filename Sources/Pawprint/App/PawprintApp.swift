import SwiftUI

@main
struct PawprintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item is managed imperatively by `StatusItemController` — SwiftUI's
        // `MenuBarExtra` label wouldn't redraw for the paw animation. Settings stays a real
        // SwiftUI scene so the standard ⌘, window and its lifecycle come for free.
        Settings {
            SettingsRootView()
        }
    }
}
