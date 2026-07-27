import Foundation
import Observation

/// Evaluates achievement conditions against a day's summary and remembers what's already been
/// unlocked. Unlocks are permanent and stored separately from daily stats, so clearing a single
/// day doesn't silently revoke a badge the user already earned.
@Observable
final class AchievementEngine {
    static let shared = AchievementEngine()

    private(set) var unlocked: [UnlockedAchievement]
    /// Set when something is newly unlocked so the popover can show a celebration, then cleared.
    private(set) var pendingCelebration: AchievementID?

    @ObservationIgnored private let store = PawprintStore.shared

    private init() {
        self.unlocked = PawprintStore.shared.loadUnlockedAchievements()
    }

    func isUnlocked(_ id: AchievementID) -> Bool {
        unlocked.contains { $0.achievementID == id.rawValue }
    }

    func unlockedRecord(_ id: AchievementID) -> UnlockedAchievement? {
        unlocked.first { $0.achievementID == id.rawValue }
    }

    /// Checks every condition against today's summary (plus the streak, which needs history).
    /// Safe to call frequently — already-unlocked achievements are skipped.
    func evaluate(summary: DailySummary, currentStreak: Int) {
        var newlyUnlocked: [AchievementID] = []

        for id in AchievementID.allCases where !isUnlocked(id) {
            if satisfies(id, summary: summary, currentStreak: currentStreak) {
                newlyUnlocked.append(id)
            }
        }

        guard !newlyUnlocked.isEmpty else { return }

        let now = Date()
        for id in newlyUnlocked {
            unlocked.append(UnlockedAchievement(achievementID: id.rawValue, unlockedOn: summary.day, unlockedAt: now))
        }
        store.saveUnlockedAchievements(unlocked)
        pendingCelebration = newlyUnlocked.first
    }

    func clearCelebration() {
        pendingCelebration = nil
    }

    func resetAll() {
        unlocked = []
        pendingCelebration = nil
        store.saveUnlockedAchievements([])
    }

    private func satisfies(_ id: AchievementID, summary: DailySummary, currentStreak: Int) -> Bool {
        switch id {
        case .firstTenThousandKeys:
            return summary.totalKeyPresses >= 10_000
        case .hundredWPM:
            return summary.maxWPM >= 100
        case .focusThirtyMinutes:
            return summary.longestFocusSeconds >= 30 * 60
        case .focusSixtyMinutes:
            return summary.longestFocusSeconds >= 60 * 60
        case .cursorOneKilometer:
            return summary.cursorDistanceMeters >= 1000
        case .scrollSkyscraper:
            return summary.scrollScreens >= 1000
        case .sevenDayStreak:
            return currentStreak >= 7
        case .nightOwl:
            return summary.activityTags.contains(.nightOwl)
        case .unpluggedMarathon:
            return summary.secondsOnBattery >= 4 * 3600
        case .multiDisplay:
            return summary.maxSimultaneousDisplays >= 3
        }
    }
}
