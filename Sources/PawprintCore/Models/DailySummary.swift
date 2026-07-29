import Foundation

package struct Highlight: Identifiable, Hashable {
    package var id: String { title }
    package var icon: String
    package var title: String
    package var detail: String
}

package struct AppUsageStat: Identifiable, Hashable {
    package var id: String { bundleID }
    package var bundleID: String
    package var appName: String
    package var totalSeconds: TimeInterval
    package var activationCount: Int
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(bundleID: String,
                 appName: String,
                 totalSeconds: TimeInterval,
                 activationCount: Int) {
        self.bundleID = bundleID
        self.appName = appName
        self.totalSeconds = totalSeconds
        self.activationCount = activationCount
    }

}

/// How much input a single app received, and how that input was split between keyboard and
/// pointer. Only counts — nothing about what was typed or clicked.
package struct AppInputProfile: Identifiable, Hashable {
    package var id: String { bundleID }
    package var bundleID: String
    package var appName: String
    package var keyPresses: Int
    package var clicks: Int
    package var scrollPoints: Double

    package var totalInput: Int { keyPresses + clicks }

    /// 0...100 — share of this app's input that came from the keyboard.
    package var keyboardSharePercent: Int {
        guard totalInput > 0 else { return 0 }
        return Int((Double(keyPresses) / Double(totalInput) * 100).rounded())
    }

    /// A short label for the app's interaction style.
    package var styleLabel: String {
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
package struct DailySummary: Identifiable {
    /// The day string is already the primary key everywhere else, so it doubles as the identity.
    package var id: String { day }
    package var day: String

    // Keyboard
    package var totalKeyPresses: Int = 0
    package var characterKeyPresses: Int = 0
    package var avgWPM: Double = 0
    package var maxWPM: Double = 0
    package var maxWPMTime: Date? = nil
    package var longestTypingStreakSeconds: Int = 0
    package var typingSessionCount: Int = 0
    package var keyCategoryCounts: [KeyCategory: Int] = [:]
    package var shortcutCounts: [ShortcutType: Int] = [:]
    package var backspaceRatio: Double = 0

    // Mouse
    package var totalClicks: Int = 0
    package var leftClicks: Int = 0
    package var rightClicks: Int = 0
    package var doubleClicks: Int = 0
    package var dragCount: Int = 0
    package var maxClicksPerMinute: Int = 0
    package var cursorDistanceMeters: Double = 0
    package var maxCursorSpeedPxPerSec: Double = 0
    /// Total scroll distance in points (device-normalized).
    package var totalScrollPoints: Double = 0
    /// Equivalent number of full screens of content scrolled, using the real display height.
    package var scrollScreens: Double = 0
    package var scrollUpPoints: Double = 0
    package var scrollDownPoints: Double = 0
    package var scrollDirectionChanges: Int = 0

    // Clipboard
    package var clipboardCopyCount: Int = 0
    package var clipboardPasteCount: Int = 0
    package var clipboardCutCount: Int = 0
    package var clipboardTypeCounts: [ClipboardDataType: Int] = [:]

    // Apps
    package var appUsage: [AppUsageStat] = []
    package var totalAppSwitches: Int = 0
    package var avgAppDwellSeconds: Double = 0
    package var shortDwellCount: Int = 0
    package var topApp: AppUsageStat? = nil

    // Time / focus
    package var firstActivity: Date? = nil
    package var lastActivity: Date? = nil
    package var activeSeconds: Int = 0
    package var idleSeconds: Int = 0
    package var activitySessionCount: Int = 0
    package var avgSessionSeconds: Double = 0
    package var focusSessionCount: Int = 0
    package var totalFocusSeconds: Int = 0
    package var longestFocusSeconds: Int = 0
    package var avgFocusSeconds: Double = 0
    package var bestFocusHour: Int? = nil
    package var topInterruptingApp: String? = nil

    // Mac state
    package var sleepCount: Int = 0
    package var wakeCount: Int = 0
    package var totalSleepSeconds: Int = 0
    package var longestSleepSeconds: Int = 0
    package var lockCount: Int = 0
    package var unlockCount: Int = 0

    // Power
    package var chargerConnectCount: Int = 0
    package var chargerDisconnectCount: Int = 0
    package var minBatteryLevel: Int? = nil
    package var maxBatteryLevel: Int? = nil
    package var currentBatteryLevel: Int? = nil
    package var secondsOnBattery: Int = 0
    package var secondsOnAC: Int = 0
    package var chargeSessionCount: Int = 0
    package var totalChargedPercent: Int = 0
    package var batteryDrainedPercent: Int = 0
    package var lowPowerModeSeconds: Int = 0
    package var elevatedThermalSeconds: Int = 0
    package var batteryTimeline: [BatterySample] = []

    // Lid
    package var lidCloseCount: Int = 0
    package var lidOpenCount: Int = 0
    package var lidClosedSeconds: Int = 0

    // Displays & audio
    package var externalDisplayConnectCount: Int = 0
    package var externalDisplayDisconnectCount: Int = 0
    package var maxSimultaneousDisplays: Int = 0
    package var audioOutputDeviceChangeCount: Int = 0
    package var displaySleepCount: Int = 0
    package var displayWakeCount: Int = 0

    // Screen time
    package var screenOnSeconds: Int = 0
    /// Screen was lit but no input happened — "켜두고 안 쓴 시간".
    package var screenIdleSeconds: Int = 0
    /// Share of screen-on time that had actual input, 0...100.
    package var screenUtilizationPercent: Int = 0

    // Extra derived detail
    package var dragDistanceMeters: Double = 0
    /// 0...100, how evenly typing was spread across active minutes.
    package var typingConsistency: Int = 0
    /// Hour of day with the highest typing speed.
    package var goldenHour: Int? = nil
    package var goldenHourWPM: Double = 0
    package var distinctShortcutsUsed: Int = 0

    // Keyboard heatmap
    package var keyCodeCounts: [UInt16: Int] = [:]
    package var mostPressedKeyLabel: String? = nil
    package var mostPressedKeyCount: Int = 0
    /// Share of keystrokes made with the left hand, 0...100.
    package var leftHandPercent: Int = 0
    package var keyRowShares: [KeyboardKey.Row: Int] = [:]
    package var distinctKeysUsed: Int = 0

    // Network
    package var networkDownloadBytes: UInt64 = 0
    package var networkUploadBytes: UInt64 = 0
    package var networkTotalBytes: UInt64 = 0
    package var peakDownloadBytesPerSec: Double = 0
    package var peakUploadBytesPerSec: Double = 0

    /// Per-app input profile, richest-first.
    package var appInputProfiles: [AppInputProfile] = []
    package var topTypingApp: AppInputProfile? = nil
    package var topClickingApp: AppInputProfile? = nil

    // App concentration
    /// 0...100 — how concentrated the day's app time was. High means one app dominated.
    package var appConcentration: Int = 0
    package var appsToReachHalfTime: Int = 0
    package var longestBreakSeconds: Int = 0
    package var doubleClickRatio: Double = 0
    /// Scrolls per click — high means a reader, low means a clicker.
    package var scrollToClickRatio: Double = 0

    // Derived / fun
    package var regretIndex: Double = 0
    package var chaosIndex: Double = 0
    package var activityTags: [ActivityTag] = []
    package var summarySentence: String = ""
    package var highlights: [Highlight] = []
    package var funFacts: [FunFact] = []
    package var score: PawprintScore? = nil
    package var persona: DailyPersona? = nil
    package var energyFacts: [FunFact] = []
    package var fingerTravelMeters: Double = 0
    package var batteryCycleCount: Int? = nil
    package var batteryHealthPercent: Int? = nil
    package var busiestMinute: Int? = nil
    package var busiestMinuteCount: Int = 0

    // Timeline
    package var activityPerMinute: [Int] = []
    package var charKeysPerMinute: [Int] = []

    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(day: String,
                 totalKeyPresses: Int = 0,
                 characterKeyPresses: Int = 0,
                 avgWPM: Double = 0,
                 maxWPM: Double = 0,
                 maxWPMTime: Date? = nil,
                 longestTypingStreakSeconds: Int = 0,
                 typingSessionCount: Int = 0,
                 keyCategoryCounts: [KeyCategory: Int] = [:],
                 shortcutCounts: [ShortcutType: Int] = [:],
                 backspaceRatio: Double = 0,
                 totalClicks: Int = 0,
                 leftClicks: Int = 0,
                 rightClicks: Int = 0,
                 doubleClicks: Int = 0,
                 dragCount: Int = 0,
                 maxClicksPerMinute: Int = 0,
                 cursorDistanceMeters: Double = 0,
                 maxCursorSpeedPxPerSec: Double = 0,
                 totalScrollPoints: Double = 0,
                 scrollScreens: Double = 0,
                 scrollUpPoints: Double = 0,
                 scrollDownPoints: Double = 0,
                 scrollDirectionChanges: Int = 0,
                 clipboardCopyCount: Int = 0,
                 clipboardPasteCount: Int = 0,
                 clipboardCutCount: Int = 0,
                 clipboardTypeCounts: [ClipboardDataType: Int] = [:],
                 appUsage: [AppUsageStat] = [],
                 totalAppSwitches: Int = 0,
                 avgAppDwellSeconds: Double = 0,
                 shortDwellCount: Int = 0,
                 topApp: AppUsageStat? = nil,
                 firstActivity: Date? = nil,
                 lastActivity: Date? = nil,
                 activeSeconds: Int = 0,
                 idleSeconds: Int = 0,
                 activitySessionCount: Int = 0,
                 avgSessionSeconds: Double = 0,
                 focusSessionCount: Int = 0,
                 totalFocusSeconds: Int = 0,
                 longestFocusSeconds: Int = 0,
                 avgFocusSeconds: Double = 0,
                 bestFocusHour: Int? = nil,
                 topInterruptingApp: String? = nil,
                 sleepCount: Int = 0,
                 wakeCount: Int = 0,
                 totalSleepSeconds: Int = 0,
                 longestSleepSeconds: Int = 0,
                 lockCount: Int = 0,
                 unlockCount: Int = 0,
                 chargerConnectCount: Int = 0,
                 chargerDisconnectCount: Int = 0,
                 minBatteryLevel: Int? = nil,
                 maxBatteryLevel: Int? = nil,
                 currentBatteryLevel: Int? = nil,
                 secondsOnBattery: Int = 0,
                 secondsOnAC: Int = 0,
                 chargeSessionCount: Int = 0,
                 totalChargedPercent: Int = 0,
                 batteryDrainedPercent: Int = 0,
                 lowPowerModeSeconds: Int = 0,
                 elevatedThermalSeconds: Int = 0,
                 batteryTimeline: [BatterySample] = [],
                 lidCloseCount: Int = 0,
                 lidOpenCount: Int = 0,
                 lidClosedSeconds: Int = 0,
                 externalDisplayConnectCount: Int = 0,
                 externalDisplayDisconnectCount: Int = 0,
                 maxSimultaneousDisplays: Int = 0,
                 audioOutputDeviceChangeCount: Int = 0,
                 displaySleepCount: Int = 0,
                 displayWakeCount: Int = 0,
                 screenOnSeconds: Int = 0,
                 screenIdleSeconds: Int = 0,
                 screenUtilizationPercent: Int = 0,
                 dragDistanceMeters: Double = 0,
                 typingConsistency: Int = 0,
                 goldenHour: Int? = nil,
                 goldenHourWPM: Double = 0,
                 distinctShortcutsUsed: Int = 0,
                 keyCodeCounts: [UInt16: Int] = [:],
                 mostPressedKeyLabel: String? = nil,
                 mostPressedKeyCount: Int = 0,
                 leftHandPercent: Int = 0,
                 keyRowShares: [KeyboardKey.Row: Int] = [:],
                 distinctKeysUsed: Int = 0,
                 networkDownloadBytes: UInt64 = 0,
                 networkUploadBytes: UInt64 = 0,
                 networkTotalBytes: UInt64 = 0,
                 peakDownloadBytesPerSec: Double = 0,
                 peakUploadBytesPerSec: Double = 0,
                 appInputProfiles: [AppInputProfile] = [],
                 topTypingApp: AppInputProfile? = nil,
                 topClickingApp: AppInputProfile? = nil,
                 appConcentration: Int = 0,
                 appsToReachHalfTime: Int = 0,
                 longestBreakSeconds: Int = 0,
                 doubleClickRatio: Double = 0,
                 scrollToClickRatio: Double = 0,
                 regretIndex: Double = 0,
                 chaosIndex: Double = 0,
                 activityTags: [ActivityTag] = [],
                 summarySentence: String = "",
                 highlights: [Highlight] = [],
                 funFacts: [FunFact] = [],
                 score: PawprintScore? = nil,
                 persona: DailyPersona? = nil,
                 energyFacts: [FunFact] = [],
                 fingerTravelMeters: Double = 0,
                 batteryCycleCount: Int? = nil,
                 batteryHealthPercent: Int? = nil,
                 busiestMinute: Int? = nil,
                 busiestMinuteCount: Int = 0,
                 activityPerMinute: [Int] = [],
                 charKeysPerMinute: [Int] = []) {
        self.day = day
        self.totalKeyPresses = totalKeyPresses
        self.characterKeyPresses = characterKeyPresses
        self.avgWPM = avgWPM
        self.maxWPM = maxWPM
        self.maxWPMTime = maxWPMTime
        self.longestTypingStreakSeconds = longestTypingStreakSeconds
        self.typingSessionCount = typingSessionCount
        self.keyCategoryCounts = keyCategoryCounts
        self.shortcutCounts = shortcutCounts
        self.backspaceRatio = backspaceRatio
        self.totalClicks = totalClicks
        self.leftClicks = leftClicks
        self.rightClicks = rightClicks
        self.doubleClicks = doubleClicks
        self.dragCount = dragCount
        self.maxClicksPerMinute = maxClicksPerMinute
        self.cursorDistanceMeters = cursorDistanceMeters
        self.maxCursorSpeedPxPerSec = maxCursorSpeedPxPerSec
        self.totalScrollPoints = totalScrollPoints
        self.scrollScreens = scrollScreens
        self.scrollUpPoints = scrollUpPoints
        self.scrollDownPoints = scrollDownPoints
        self.scrollDirectionChanges = scrollDirectionChanges
        self.clipboardCopyCount = clipboardCopyCount
        self.clipboardPasteCount = clipboardPasteCount
        self.clipboardCutCount = clipboardCutCount
        self.clipboardTypeCounts = clipboardTypeCounts
        self.appUsage = appUsage
        self.totalAppSwitches = totalAppSwitches
        self.avgAppDwellSeconds = avgAppDwellSeconds
        self.shortDwellCount = shortDwellCount
        self.topApp = topApp
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
        self.activeSeconds = activeSeconds
        self.idleSeconds = idleSeconds
        self.activitySessionCount = activitySessionCount
        self.avgSessionSeconds = avgSessionSeconds
        self.focusSessionCount = focusSessionCount
        self.totalFocusSeconds = totalFocusSeconds
        self.longestFocusSeconds = longestFocusSeconds
        self.avgFocusSeconds = avgFocusSeconds
        self.bestFocusHour = bestFocusHour
        self.topInterruptingApp = topInterruptingApp
        self.sleepCount = sleepCount
        self.wakeCount = wakeCount
        self.totalSleepSeconds = totalSleepSeconds
        self.longestSleepSeconds = longestSleepSeconds
        self.lockCount = lockCount
        self.unlockCount = unlockCount
        self.chargerConnectCount = chargerConnectCount
        self.chargerDisconnectCount = chargerDisconnectCount
        self.minBatteryLevel = minBatteryLevel
        self.maxBatteryLevel = maxBatteryLevel
        self.currentBatteryLevel = currentBatteryLevel
        self.secondsOnBattery = secondsOnBattery
        self.secondsOnAC = secondsOnAC
        self.chargeSessionCount = chargeSessionCount
        self.totalChargedPercent = totalChargedPercent
        self.batteryDrainedPercent = batteryDrainedPercent
        self.lowPowerModeSeconds = lowPowerModeSeconds
        self.elevatedThermalSeconds = elevatedThermalSeconds
        self.batteryTimeline = batteryTimeline
        self.lidCloseCount = lidCloseCount
        self.lidOpenCount = lidOpenCount
        self.lidClosedSeconds = lidClosedSeconds
        self.externalDisplayConnectCount = externalDisplayConnectCount
        self.externalDisplayDisconnectCount = externalDisplayDisconnectCount
        self.maxSimultaneousDisplays = maxSimultaneousDisplays
        self.audioOutputDeviceChangeCount = audioOutputDeviceChangeCount
        self.displaySleepCount = displaySleepCount
        self.displayWakeCount = displayWakeCount
        self.screenOnSeconds = screenOnSeconds
        self.screenIdleSeconds = screenIdleSeconds
        self.screenUtilizationPercent = screenUtilizationPercent
        self.dragDistanceMeters = dragDistanceMeters
        self.typingConsistency = typingConsistency
        self.goldenHour = goldenHour
        self.goldenHourWPM = goldenHourWPM
        self.distinctShortcutsUsed = distinctShortcutsUsed
        self.keyCodeCounts = keyCodeCounts
        self.mostPressedKeyLabel = mostPressedKeyLabel
        self.mostPressedKeyCount = mostPressedKeyCount
        self.leftHandPercent = leftHandPercent
        self.keyRowShares = keyRowShares
        self.distinctKeysUsed = distinctKeysUsed
        self.networkDownloadBytes = networkDownloadBytes
        self.networkUploadBytes = networkUploadBytes
        self.networkTotalBytes = networkTotalBytes
        self.peakDownloadBytesPerSec = peakDownloadBytesPerSec
        self.peakUploadBytesPerSec = peakUploadBytesPerSec
        self.appInputProfiles = appInputProfiles
        self.topTypingApp = topTypingApp
        self.topClickingApp = topClickingApp
        self.appConcentration = appConcentration
        self.appsToReachHalfTime = appsToReachHalfTime
        self.longestBreakSeconds = longestBreakSeconds
        self.doubleClickRatio = doubleClickRatio
        self.scrollToClickRatio = scrollToClickRatio
        self.regretIndex = regretIndex
        self.chaosIndex = chaosIndex
        self.activityTags = activityTags
        self.summarySentence = summarySentence
        self.highlights = highlights
        self.funFacts = funFacts
        self.score = score
        self.persona = persona
        self.energyFacts = energyFacts
        self.fingerTravelMeters = fingerTravelMeters
        self.batteryCycleCount = batteryCycleCount
        self.batteryHealthPercent = batteryHealthPercent
        self.busiestMinute = busiestMinute
        self.busiestMinuteCount = busiestMinuteCount
        self.activityPerMinute = activityPerMinute
        self.charKeysPerMinute = charKeysPerMinute
    }

}
