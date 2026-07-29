import Foundation

/// Canonical descriptions of the derived indices, kept in one place so the popover text and any
/// future copy can't drift apart.
/// Shared explanation copy, stored as *keys*.
///
/// These used to be `static let` tuples of resolved strings, which froze whatever language was
/// active the first time the type was touched — and since `MetricCatalog.all` is built while
/// settings are still decoding, that could be before any pack had loaded, baking in raw keys.
/// `Keys` holds the identifiers; the computed properties resolve them on every read.
package enum MetricExplanations {
    package enum Keys {
        package static let regret = (title: "infoBadge.d32aef3b", body: "infoBadge.3ac264d8", detail: "infoBadge.c5e70d8c")
        package static let chaos = (title: "infoBadge.8d82b6ef", body: "infoBadge.67ad806d", detail: "infoBadge.379e7d58")
        package static let score = (title: "infoBadge.c0849f0a", body: "infoBadge.ccaddf17", detail: "infoBadge.dfcc74df")
        package static let persona = (title: "infoBadge.64ee2fc5", body: "infoBadge.6783ea14", detail: "infoBadge.5bb0c341")
        package static let focus = (title: "infoBadge.dcb92d2f", body: "infoBadge.bc617bb0", detail: "infoBadge.487b65e7")
        package static let screenTime = (title: "infoBadge.e5e7450c", body: "infoBadge.060f778c", detail: "infoBadge.53e3ef50")
        package static let network = (title: "infoBadge.d182eb6a", body: "infoBadge.9283801c", detail: "infoBadge.5f783ec6")
        package static let keyboardHeatmap = (title: "infoBadge.d0bd899a", body: "infoBadge.d5b39aee", detail: "infoBadge.89e7602a")
        package static let appConcentration = (title: "infoBadge.c8d17c79", body: "infoBadge.97ccf128", detail: "infoBadge.894f8154")
        package static let energy = (title: "infoBadge.1ba83489", body: "infoBadge.176f76b7", detail: "infoBadge.5f0c365d")
        package static let level = (title: "infoBadge.243c18f1", body: "infoBadge.16b08d2b", detail: "infoBadge.018ff480")
    }

    package static var regret: (title: String, body: String, detail: String) {
        (L10n.t(Keys.regret.title), L10n.t(Keys.regret.body), L10n.t(Keys.regret.detail))
    }

    package static var chaos: (title: String, body: String, detail: String) {
        (L10n.t(Keys.chaos.title), L10n.t(Keys.chaos.body), L10n.t(Keys.chaos.detail))
    }

    package static var score: (title: String, body: String, detail: String) {
        (L10n.t(Keys.score.title), L10n.t(Keys.score.body), L10n.t(Keys.score.detail))
    }

    package static var persona: (title: String, body: String, detail: String) {
        (L10n.t(Keys.persona.title), L10n.t(Keys.persona.body), L10n.t(Keys.persona.detail))
    }

    package static var focus: (title: String, body: String, detail: String) {
        (L10n.t(Keys.focus.title), L10n.t(Keys.focus.body), L10n.t(Keys.focus.detail))
    }

    package static var screenTime: (title: String, body: String, detail: String) {
        (L10n.t(Keys.screenTime.title), L10n.t(Keys.screenTime.body), L10n.t(Keys.screenTime.detail))
    }

    package static var network: (title: String, body: String, detail: String) {
        (L10n.t(Keys.network.title), L10n.t(Keys.network.body), L10n.t(Keys.network.detail))
    }

    package static var keyboardHeatmap: (title: String, body: String, detail: String) {
        (L10n.t(Keys.keyboardHeatmap.title), L10n.t(Keys.keyboardHeatmap.body), L10n.t(Keys.keyboardHeatmap.detail))
    }

    package static var appConcentration: (title: String, body: String, detail: String) {
        (L10n.t(Keys.appConcentration.title), L10n.t(Keys.appConcentration.body), L10n.t(Keys.appConcentration.detail))
    }

    package static var energy: (title: String, body: String, detail: String) {
        (L10n.t(Keys.energy.title), L10n.t(Keys.energy.body), L10n.t(Keys.energy.detail))
    }

    package static var level: (title: String, body: String, detail: String) {
        (L10n.t(Keys.level.title), L10n.t(Keys.level.body), L10n.t(Keys.level.detail))
    }

}
