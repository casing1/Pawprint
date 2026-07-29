import Foundation

/// Distribution constants, kept outside the `@MainActor` class so non-isolated types such as
/// `AppSettings` can read them without hopping actors.
package enum UpdateDistribution {
    /// Public half of the update signing key. The private half is a GitHub Actions secret.
    /// Changing this invalidates every previously published release — rotate deliberately.
    package static let publicKey = "WFrwhuof35wfjgGTjm5WwGXW8BlHb6DnXYKNcfoOiBc="

    /// GitHub Releases for this repository. Ships as the default so a fresh install already
    /// knows where updates come from; the setting itself is still off until the user opts in.
    package static let feedURL = "https://api.github.com/repos/yhcho0405/Pawprint/releases/latest"
}
