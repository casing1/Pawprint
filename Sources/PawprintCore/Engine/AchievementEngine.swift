import Foundation
import Observation

/// Evaluates achievement conditions against a day's summary and remembers what's already been
/// unlocked. Unlocks are permanent and stored separately from daily stats, so clearing a single
/// day doesn't silently revoke a badge the user already earned.
@Observable
final package class AchievementEngine {
    static package let shared = AchievementEngine()
    // `package var`, not `package private(set) var`. The two are equivalent to every caller here —
    // nothing outside this type assigns to them — but the Observation macro on the CI toolchain
    // copies the modifier list into its generated accessors and emits a duplicate, which is a
    // build failure rather than a warning. Keeping the setter package-visible is the smaller cost.

    package var unlocked: [UnlockedAchievement]
    /// Set when something is newly unlocked so the popover can show a celebration, then cleared.
    package var pendingCelebration: AchievementID?

    @ObservationIgnored private let store = PawprintStore.shared

    private init() {
        self.unlocked = PawprintStore.shared.loadUnlockedAchievements()
    }

    package func isUnlocked(_ id: AchievementID) -> Bool {
        unlocked.contains { $0.achievementID == id.rawValue }
    }

    package func unlockedRecord(_ id: AchievementID) -> UnlockedAchievement? {
        unlocked.first { $0.achievementID == id.rawValue }
    }

    /// Checks every condition against today's summary (plus the streak, which needs history).
    /// Safe to call frequently — already-unlocked achievements are skipped.
    package func evaluate(summary: DailySummary, currentStreak: Int) {
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

    package func clearCelebration() {
        pendingCelebration = nil
    }

    package func resetAll() {
        unlocked = []
        pendingCelebration = nil
        store.saveUnlockedAchievements([])
    }

    /// Pure: reads nothing but its arguments. Not private so `DebugSnapshot` can check every
    /// condition against a purpose-built summary without writing unlocks to the real store.
    package func satisfies(_ id: AchievementID, summary: DailySummary, currentStreak: Int) -> Bool {
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

        // Hidden. Each looks for an unusual *shape* in the day rather than a bigger number, so
        // they can't be reached by simply doing more of something — which is what keeps them
        // worth discovering. None of them judge the day; they only notice it.
        case .witchingHour:
            // Any activity inside the 3am hour. `activityPerMinute` is indexed by minute of day.
            return summary.activityPerMinute.count > 240
                && summary.activityPerMinute[180..<240].contains { $0 > 0 }
        case .oneHandedWonder:
            return summary.totalKeyPresses >= 2_000
                && (summary.leftHandPercent >= 75 || summary.leftHandPercent <= 25)
        case .tunnelVision:
            return summary.appConcentration >= 95 && summary.activeSeconds >= 4 * 3600
        case .stormMinute:
            return summary.busiestMinuteCount >= 400
        case .lidFlipper:
            return summary.lidOpenCount >= 10
        case .fullyIndependent:
            return summary.secondsOnBattery >= 8 * 3600 && summary.chargerConnectCount == 0
        case .perfectBalance:
            // Scrolled a long way and ended up almost exactly where you started.
            let total = summary.scrollUpPoints + summary.scrollDownPoints
            guard summary.scrollScreens >= 100, total > 0 else { return false }
            return abs(summary.scrollUpPoints - summary.scrollDownPoints) / total <= 0.03
        case .fullKeyboard:
            return summary.distinctKeysUsed >= 60
        case .quietKeys:
            return summary.activeSeconds >= 4 * 3600
                && summary.totalKeyPresses >= 3_000
                && summary.totalClicks <= 100
        }
    }
}
