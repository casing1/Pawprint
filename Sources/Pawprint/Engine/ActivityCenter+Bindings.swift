import SwiftUI

/// Convenience two-way `Binding`s into `AppSettings` for SwiftUI controls, funneled through
/// `updateSettings(_:)` so every write still gets persisted and re-evaluated (exclusion state,
/// dock icon policy, etc.) in one place.
extension ActivityCenter {
    /// Compact mode changes the HUD's intrinsic size, so the panel is re-fitted after the setting
    /// lands rather than leaving a window sized for the other layout.
    func setHUDCompact(_ compact: Bool) {
        var updated = settings
        updated.hudCompact = compact
        updateSettings(updated)
        DispatchQueue.main.async {
            MainActor.assumeIsolated { LiveHUDController.shared.refreshSize() }
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                var s = self.settings
                s[keyPath: keyPath] = newValue
                self.updateSettings(s)
            }
        )
    }
}
