import Foundation
import PawprintCore

/// The deliberately small, adventure-only progression record.
///
/// Activity-derived cat grades and Pawprint statistics never enter this store. A run can award
/// only adventure XP, route stamps, and one bond point for each participating cat.
struct AdventureRewardProgress: Codable, Equatable {
    var adventureXP: Int
    var completedRuns: Int
    var routeStamps: [String: Int]
    var catBonds: [String: Int]
    var appliedGrantIDs: [String]

    static let empty = AdventureRewardProgress(
        adventureXP: 0,
        completedRuns: 0,
        routeStamps: [:],
        catBonds: [:],
        appliedGrantIDs: []
    )

    var level: Int {
        adventureXP / 250 + 1
    }

    var experienceWithinLevel: Int {
        adventureXP % 250
    }

    var experiencePerLevel: Int { 250 }

    func stampCount(for routeID: String) -> Int {
        routeStamps[routeID, default: 0]
    }
}

/// Applies each pure-engine reward grant at most once and persists only aggregate progression.
///
/// The active run stays in memory. This store is intentionally independent of `PawprintStore`
/// so adventure rewards cannot alter activity history, scores, or cat rarity.
@MainActor
final class AdventureRewardStore {
    static let shared = AdventureRewardStore(
        store: .shared,
        legacyDefaults: .standard
    )

    private static let defaultKey = "adventure.rewardProgress.v1"
    /// An active expedition is not restored after relaunch, so old grants can never be submitted
    /// again. A short tail is enough to defend against duplicate callbacks without turning every
    /// reward into an ever-growing linear scan and full-file rewrite.
    static let grantHistoryLimit = 256

    private let saveData: (Data) -> Void
    private let deleteData: () -> Void
    private(set) var progress: AdventureRewardProgress

    init(
        defaults: UserDefaults,
        key: String? = nil
    ) {
        let key = key ?? Self.defaultKey
        saveData = { defaults.set($0, forKey: key) }
        deleteData = { defaults.removeObject(forKey: key) }
        progress = Self.load(data: defaults.data(forKey: key))
    }

    /// Production persistence stays inside Pawprint's SQLite database. The one-time preferences
    /// read migrates development builds made before this storage boundary was corrected.
    private init(
        store: PawprintStore,
        legacyDefaults: UserDefaults
    ) {
        let legacyKey = Self.defaultKey
        var initialData = store.loadAdventureProgressData()
        if initialData == nil,
           let legacyData = legacyDefaults.data(forKey: legacyKey) {
            initialData = legacyData
            store.saveAdventureProgressData(legacyData)
            legacyDefaults.removeObject(forKey: legacyKey)
        }

        saveData = { store.saveAdventureProgressData($0) }
        deleteData = {
            store.deleteAdventureProgressData()
            legacyDefaults.removeObject(forKey: legacyKey)
        }
        progress = Self.load(data: initialData)
    }

    /// Returns true only when a previously unseen grant changed the stored progression.
    @discardableResult
    func apply(_ reward: AdventurePermanentReward) -> Bool {
        guard reward.adventureXP > 0
                || reward.routeStampDelta > 0
                || reward.bondGains.contains(where: { $0.amount > 0 })
        else {
            return false
        }
        guard !progress.appliedGrantIDs.contains(reward.grantID) else {
            return false
        }

        var updated = progress
        updated.appliedGrantIDs.append(reward.grantID)
        if updated.appliedGrantIDs.count > Self.grantHistoryLimit {
            updated.appliedGrantIDs.removeFirst(
                updated.appliedGrantIDs.count - Self.grantHistoryLimit
            )
        }

        updated.adventureXP += max(0, reward.adventureXP)
        if reward.routeStampDelta > 0 {
            updated.completedRuns += 1
            updated.routeStamps[reward.routeID, default: 0] +=
                reward.routeStampDelta
        }
        for gain in reward.bondGains where gain.amount > 0 {
            updated.catBonds[gain.catID, default: 0] += gain.amount
        }

        progress = updated
        persist()
        return true
    }

    func deleteBond(for day: String) {
        guard progress.catBonds.removeValue(forKey: day) != nil else {
            return
        }
        persist()
    }

    func deleteBonds(before day: String) {
        let retained = progress.catBonds.filter { $0.key >= day }
        guard retained.count != progress.catBonds.count else { return }
        progress.catBonds = retained
        persist()
    }

    func reset() {
        progress = .empty
        deleteData()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        saveData(data)
    }

    private static func load(data: Data?) -> AdventureRewardProgress {
        guard
            let data,
            var decoded = try? JSONDecoder().decode(
                AdventureRewardProgress.self,
                from: data
            )
        else {
            return .empty
        }

        decoded.adventureXP = max(0, decoded.adventureXP)
        decoded.completedRuns = max(0, decoded.completedRuns)
        decoded.routeStamps = decoded.routeStamps.mapValues { max(0, $0) }
        decoded.catBonds = decoded.catBonds.mapValues { max(0, $0) }
        var seen: Set<String> = []
        decoded.appliedGrantIDs = Array(
            decoded.appliedGrantIDs
                .reversed()
                .filter { seen.insert($0).inserted }
                .prefix(Self.grantHistoryLimit)
                .reversed()
        )
        return decoded
    }
}
