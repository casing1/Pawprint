import Foundation

struct Highlight: Identifiable, Hashable {
    var id: String { title }
    var icon: String
    var title: String
    var detail: String
}

struct AppUsageStat: Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var appName: String
    var totalSeconds: TimeInterval
    var activationCount: Int
}

/// How much input a single app received, and how that input was split between keyboard and
/// pointer. Only counts — nothing about what was typed or clicked.
struct AppInputProfile: Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var appName: String
    var keyPresses: Int
    var clicks: Int
    var scrollPoints: Double

    var totalInput: Int { keyPresses + clicks }

    /// 0...100 — share of this app's input that came from the keyboard.
    var keyboardSharePercent: Int {
        guard totalInput > 0 else { return 0 }
        return Int((Double(keyPresses) / Double(totalInput) * 100).rounded())
    }

    /// A short label for the app's interaction style.
    var styleLabel: String {
        switch keyboardSharePercent {
        case 80...: return L10n.t("dailySummary.ac5ff6f8")
        case 60..<80: return L10n.t("dailySummary.b9a745bb")
        case 40..<60: return L10n.t("dailySummary.70b75ce7")
        case 20..<40: return L10n.t("dailySummary.010711c4")
        default: return L10n.t("dailySummary.53745d5c")
        }
    }
}

/// Fully derived, display-ready snapshot of one day. Built by `StatsEngine` from `DailyRawCounters`.
struct DailySummary: Identifiable {
    /// The day string is already the primary key everywhere else, so it doubles as the identity.
    var id: String { day }
    var day: String

    // Keyboard
    var totalKeyPresses: Int = 0
    var characterKeyPresses: Int = 0
    var avgWPM: Double = 0
    var maxWPM: Double = 0
    var maxWPMTime: Date? = nil
    var longestTypingStreakSeconds: Int = 0
    var typingSessionCount: Int = 0
    var keyCategoryCounts: [KeyCategory: Int] = [:]
    var shortcutCounts: [ShortcutType: Int] = [:]
    var backspaceRatio: Double = 0

    // Mouse
    var totalClicks: Int = 0
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var doubleClicks: Int = 0
    var dragCount: Int = 0
    var maxClicksPerMinute: Int = 0
    var cursorDistanceMeters: Double = 0
    var maxCursorSpeedPxPerSec: Double = 0
    /// Total scroll distance in points (device-normalized).
    var totalScrollPoints: Double = 0
    /// Equivalent number of full screens of content scrolled, using the real display height.
    var scrollScreens: Double = 0
    var scrollUpPoints: Double = 0
    var scrollDownPoints: Double = 0
    var scrollDirectionChanges: Int = 0

    // Clipboard
    var clipboardCopyCount: Int = 0
    var clipboardPasteCount: Int = 0
    var clipboardCutCount: Int = 0
    var clipboardTypeCounts: [ClipboardDataType: Int] = [:]

    // Apps
    var appUsage: [AppUsageStat] = []
    var totalAppSwitches: Int = 0
    var avgAppDwellSeconds: Double = 0
    var shortDwellCount: Int = 0
    var topApp: AppUsageStat? = nil

    // Time / focus
    var firstActivity: Date? = nil
    var lastActivity: Date? = nil
    var activeSeconds: Int = 0
    var idleSeconds: Int = 0
    var activitySessionCount: Int = 0
    var avgSessionSeconds: Double = 0
    var focusSessionCount: Int = 0
    var totalFocusSeconds: Int = 0
    var longestFocusSeconds: Int = 0
    var avgFocusSeconds: Double = 0
    var bestFocusHour: Int? = nil
    var topInterruptingApp: String? = nil

    // Mac state
    var sleepCount: Int = 0
    var wakeCount: Int = 0
    var totalSleepSeconds: Int = 0
    var longestSleepSeconds: Int = 0
    var lockCount: Int = 0
    var unlockCount: Int = 0

    // Power
    var chargerConnectCount: Int = 0
    var chargerDisconnectCount: Int = 0
    var minBatteryLevel: Int? = nil
    var maxBatteryLevel: Int? = nil
    var currentBatteryLevel: Int? = nil
    var secondsOnBattery: Int = 0
    var secondsOnAC: Int = 0
    var chargeSessionCount: Int = 0
    var totalChargedPercent: Int = 0
    var batteryDrainedPercent: Int = 0
    var lowPowerModeSeconds: Int = 0
    var elevatedThermalSeconds: Int = 0
    var batteryTimeline: [BatterySample] = []

    // Lid
    var lidCloseCount: Int = 0
    var lidOpenCount: Int = 0
    var lidClosedSeconds: Int = 0

    // Displays & audio
    var externalDisplayConnectCount: Int = 0
    var externalDisplayDisconnectCount: Int = 0
    var maxSimultaneousDisplays: Int = 0
    var audioOutputDeviceChangeCount: Int = 0
    var displaySleepCount: Int = 0
    var displayWakeCount: Int = 0

    // Screen time
    var screenOnSeconds: Int = 0
    /// Screen was lit but no input happened — "켜두고 안 쓴 시간".
    var screenIdleSeconds: Int = 0
    /// Share of screen-on time that had actual input, 0...100.
    var screenUtilizationPercent: Int = 0

    // Extra derived detail
    var dragDistanceMeters: Double = 0
    /// 0...100, how evenly typing was spread across active minutes.
    var typingConsistency: Int = 0
    /// Hour of day with the highest typing speed.
    var goldenHour: Int? = nil
    var goldenHourWPM: Double = 0
    var distinctShortcutsUsed: Int = 0

    // Keyboard heatmap
    var keyCodeCounts: [UInt16: Int] = [:]
    var mostPressedKeyLabel: String? = nil
    var mostPressedKeyCount: Int = 0
    /// Share of keystrokes made with the left hand, 0...100.
    var leftHandPercent: Int = 0
    var keyRowShares: [KeyboardKey.Row: Int] = [:]
    var distinctKeysUsed: Int = 0

    // Network
    var networkDownloadBytes: UInt64 = 0
    var networkUploadBytes: UInt64 = 0
    var networkTotalBytes: UInt64 = 0
    var peakDownloadBytesPerSec: Double = 0
    var peakUploadBytesPerSec: Double = 0

    /// Per-app input profile, richest-first.
    var appInputProfiles: [AppInputProfile] = []
    var topTypingApp: AppInputProfile? = nil
    var topClickingApp: AppInputProfile? = nil

    // App concentration
    /// 0...100 — how concentrated the day's app time was. High means one app dominated.
    var appConcentration: Int = 0
    var appsToReachHalfTime: Int = 0
    var longestBreakSeconds: Int = 0
    var doubleClickRatio: Double = 0
    /// Scrolls per click — high means a reader, low means a clicker.
    var scrollToClickRatio: Double = 0

    // Derived / fun
    var regretIndex: Double = 0
    var chaosIndex: Double = 0
    var activityTags: [ActivityTag] = []
    var summarySentence: String = ""
    var highlights: [Highlight] = []
    var funFacts: [FunFact] = []
    var score: PawprintScore? = nil
    var persona: DailyPersona? = nil
    var energyFacts: [FunFact] = []
    var fingerTravelMeters: Double = 0
    var batteryCycleCount: Int? = nil
    var batteryHealthPercent: Int? = nil
    var busiestMinute: Int? = nil
    var busiestMinuteCount: Int = 0

    // Timeline
    var activityPerMinute: [Int] = []
    var charKeysPerMinute: [Int] = []

}
