import Foundation

/// One activation period of a single app. `appName` is the human-readable name;
/// never any window title, document name, or URL is captured.
package struct AppSessionRecord: Codable, Identifiable, Hashable {
    package var id: UUID = UUID()
    package var bundleID: String
    package var appName: String
    package var start: Date
    package var end: Date

    package var duration: TimeInterval { end.timeIntervalSince(start) }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(id: UUID = UUID(),
                 bundleID: String,
                 appName: String,
                 start: Date,
                 end: Date) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.start = start
        self.end = end
    }

}

/// A stretch of continuous work inside one app (or a small cluster of related apps).
package struct FocusSessionRecord: Codable, Identifiable, Hashable {
    package var id: UUID = UUID()
    package var start: Date
    package var end: Date
    package var primaryApp: String
    package var interruptionCount: Int = 0

    package var duration: TimeInterval { end.timeIntervalSince(start) }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(id: UUID = UUID(),
                 start: Date,
                 end: Date,
                 primaryApp: String,
                 interruptionCount: Int = 0) {
        self.id = id
        self.start = start
        self.end = end
        self.primaryApp = primaryApp
        self.interruptionCount = interruptionCount
    }

}

/// A stretch of continuous activity separated from neighboring activity by an idle gap.
package struct ActivitySessionRecord: Codable, Identifiable, Hashable {
    package var id: UUID = UUID()
    package var start: Date
    package var end: Date

    package var duration: TimeInterval { end.timeIntervalSince(start) }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(id: UUID = UUID(),
                 start: Date,
                 end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }

}

package struct SleepWakeRecord: Codable, Identifiable, Hashable {
    package var id: UUID = UUID()
    package var type: MacStateEventType
    package var timestamp: Date
    package var durationSeconds: Int = 0
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(id: UUID = UUID(),
                 type: MacStateEventType,
                 timestamp: Date,
                 durationSeconds: Int = 0) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }

}

package struct BatterySample: Codable, Hashable {
    package var timestamp: Date
    package var level: Int
    package var isCharging: Bool
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(timestamp: Date,
                 level: Int,
                 isCharging: Bool) {
        self.timestamp = timestamp
        self.level = level
        self.isCharging = isCharging
    }

}

/// One plugged-in period, from charger connect to disconnect.
package struct ChargeSessionRecord: Codable, Identifiable, Hashable {
    package var id: UUID = UUID()
    package var start: Date
    package var end: Date?
    package var startLevel: Int
    package var endLevel: Int?

    package var gainedPercent: Int? {
        guard let endLevel else { return nil }
        return max(0, endLevel - startLevel)
    }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(id: UUID = UUID(),
                 start: Date,
                 end: Date? = nil,
                 startLevel: Int,
                 endLevel: Int? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.startLevel = startLevel
        self.endLevel = endLevel
    }

}

/// Everything Pawprint records about a single calendar day, as raw counters.
/// This is the only thing persisted to disk; every derived number (WPM, indices,
/// highlights, sentences) is computed from this at read time by `StatsEngine`.
///
/// Decoding is deliberately hand-written with `decodeIfPresent` throughout: Swift's synthesized
/// `Decodable` throws `keyNotFound` for any field missing from stored JSON *even when the
/// property has a default value*, which would silently discard a user's entire history the
/// first time a new metric is added. Every field here must stay optional-on-read.
package struct DailyRawCounters: Codable {
    static package let minutesPerDay = 24 * 60

    package var day: String

    // MARK: Keyboard
    package var totalKeyPresses: Int = 0
    package var characterKeyPresses: Int = 0
    package var keyCategoryCounts: [String: Int] = [:]
    package var shortcutCounts: [String: Int] = [:]
    /// Press count per physical key, keyed by macOS virtual key code. This is an unordered
    /// frequency table for the heatmap — it records *which key on the board* was pressed and how
    /// often, never the sequence and never the character produced (which depends on layout,
    /// modifiers, and IME state that Pawprint deliberately doesn't read).
    package var keyCodeCounts: [String: Int] = [:]
    /// Character-key presses bucketed by minute-of-day (0...1439). Used for WPM-over-time only —
    /// no key identity or order is retained, just a count per minute.
    package var charKeysPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)
    package var maxWPM: Double = 0
    package var maxWPMMinute: Int? = nil
    package var longestTypingStreakSeconds: Int = 0
    package var typingSessionCount: Int = 0

    // MARK: Mouse / trackpad
    package var leftClicks: Int = 0
    package var rightClicks: Int = 0
    package var doubleClicks: Int = 0
    package var dragCount: Int = 0
    package var clicksPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)
    package var cursorDistancePixels: Double = 0
    package var maxCursorSpeedPxPerSec: Double = 0
    package var idleCursorSeconds: Int = 0

    /// Scroll distance in **points**, normalized across input devices.
    ///
    /// `NSEvent.scrollingDeltaY` is in points for precise devices (trackpad, Magic Mouse) but in
    /// *lines* for classic notched wheels; treating both as lines over-counted trackpad scrolling
    /// by more than an order of magnitude. `MouseMonitor` now converts line-based deltas to
    /// points before accumulating here.
    package var scrollUpPoints: Double = 0
    package var scrollDownPoints: Double = 0
    package var scrollHorizontalPoints: Double = 0
    package var scrollDirectionChanges: Int = 0
    package var maxScrollSpeedPointsPerSec: Double = 0
    package var scrollPerMinute: [Double] = Array(repeating: 0, count: minutesPerDay)

    /// Combined keyboard+mouse intensity per minute, drives the "오늘" mini timeline sparkline.
    package var activityPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)

    // MARK: Clipboard
    package var clipboardCopyCount: Int = 0
    package var clipboardPasteCount: Int = 0
    package var clipboardCutCount: Int = 0
    package var clipboardTypeCounts: [String: Int] = [:]

    // MARK: App usage
    package var appSessions: [AppSessionRecord] = []
    package var totalAppSwitches: Int = 0
    package var shortDwellCount: Int = 0
    package var appLaunchCounts: [String: Int] = [:]
    package var appTerminateCounts: [String: Int] = [:]

    /// Input attributed to whichever app was frontmost at the time, keyed by bundle id.
    /// Counts only — never which keys, in what order, or what was clicked on. Excluded apps are
    /// filtered upstream, so nothing is attributed to them.
    package var appKeyPresses: [String: Int] = [:]
    package var appClicks: [String: Int] = [:]
    package var appScrollPoints: [String: Double] = [:]
    /// Display names for the bundle ids above, so history stays readable if an app is uninstalled.
    package var appNames: [String: String] = [:]

    // MARK: Focus
    package var focusSessions: [FocusSessionRecord] = []
    package var focusInterruptionsByApp: [String: Int] = [:]

    // MARK: Active / idle time
    package var firstActivity: Date? = nil
    package var lastActivity: Date? = nil
    package var activeSeconds: Int = 0
    package var activitySessions: [ActivitySessionRecord] = []

    // MARK: Mac state
    package var sleepWakeEvents: [SleepWakeRecord] = []
    package var lockCount: Int = 0
    package var unlockCount: Int = 0
    package var chargerConnectCount: Int = 0
    package var chargerDisconnectCount: Int = 0
    package var batterySamples: [BatterySample] = []

    // MARK: Power detail
    package var chargeSessions: [ChargeSessionRecord] = []
    package var secondsOnBattery: Int = 0
    package var secondsOnAC: Int = 0
    package var lowPowerModeSeconds: Int = 0
    /// Seconds spent in a thermal state above `.nominal`.
    package var elevatedThermalSeconds: Int = 0

    // MARK: Lid (clamshell)
    package var lidCloseCount: Int = 0
    package var lidOpenCount: Int = 0
    package var lidClosedSeconds: Int = 0

    // MARK: Displays & audio
    package var externalDisplayConnectCount: Int = 0
    package var externalDisplayDisconnectCount: Int = 0
    package var maxSimultaneousDisplays: Int = 0
    package var audioOutputDeviceChangeCount: Int = 0
    package var displaySleepCount: Int = 0
    package var displayWakeCount: Int = 0
    /// Wall-clock seconds the display was actually lit — distinct from `activeSeconds`, which
    /// only counts stretches with real input. The gap between them is "screen on, but idle".
    package var screenOnSeconds: Int = 0

    // MARK: Extra pointer detail
    package var dragDistancePoints: Double = 0

    // MARK: Network
    /// Bytes transferred across physical network interfaces. Totals only — no hosts, ports,
    /// or contents are ever observed.
    package var networkDownloadBytes: UInt64 = 0
    package var networkUploadBytes: UInt64 = 0
    package var peakDownloadBytesPerSec: Double = 0
    package var peakUploadBytesPerSec: Double = 0

    package init(day: String) {
        self.day = day
    }

    // MARK: - Forward/backward-compatible coding

    private enum CodingKeys: String, CodingKey {
        case day
        case totalKeyPresses, characterKeyPresses, keyCategoryCounts, shortcutCounts, keyCodeCounts
        case charKeysPerMinute, maxWPM, maxWPMMinute, longestTypingStreakSeconds, typingSessionCount
        case leftClicks, rightClicks, doubleClicks, dragCount, clicksPerMinute
        case cursorDistancePixels, maxCursorSpeedPxPerSec, idleCursorSeconds
        case scrollUpPoints, scrollDownPoints, scrollHorizontalPoints
        case scrollDirectionChanges, maxScrollSpeedPointsPerSec, scrollPerMinute
        case activityPerMinute
        case clipboardCopyCount, clipboardPasteCount, clipboardCutCount, clipboardTypeCounts
        case appSessions, totalAppSwitches, shortDwellCount, appLaunchCounts, appTerminateCounts
        case appKeyPresses, appClicks, appScrollPoints, appNames
        case focusSessions, focusInterruptionsByApp
        case firstActivity, lastActivity, activeSeconds, activitySessions
        case sleepWakeEvents, lockCount, unlockCount
        case chargerConnectCount, chargerDisconnectCount, batterySamples
        case chargeSessions, secondsOnBattery, secondsOnAC, lowPowerModeSeconds, elevatedThermalSeconds
        case lidCloseCount, lidOpenCount, lidClosedSeconds
        case externalDisplayConnectCount, externalDisplayDisconnectCount, maxSimultaneousDisplays
        case audioOutputDeviceChangeCount, displaySleepCount, displayWakeCount, screenOnSeconds
        case dragDistancePoints
        case networkDownloadBytes, networkUploadBytes
        case peakDownloadBytesPerSec, peakUploadBytesPerSec
    }

    package init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func i(_ k: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: k) ?? 0 }
        func d(_ k: CodingKeys) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? 0 }

        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""

        totalKeyPresses = try i(.totalKeyPresses)
        characterKeyPresses = try i(.characterKeyPresses)
        keyCategoryCounts = try c.decodeIfPresent([String: Int].self, forKey: .keyCategoryCounts) ?? [:]
        shortcutCounts = try c.decodeIfPresent([String: Int].self, forKey: .shortcutCounts) ?? [:]
        keyCodeCounts = try c.decodeIfPresent([String: Int].self, forKey: .keyCodeCounts) ?? [:]
        charKeysPerMinute = Self.normalizedInts(try c.decodeIfPresent([Int].self, forKey: .charKeysPerMinute))
        maxWPM = try d(.maxWPM)
        maxWPMMinute = try c.decodeIfPresent(Int.self, forKey: .maxWPMMinute)
        longestTypingStreakSeconds = try i(.longestTypingStreakSeconds)
        typingSessionCount = try i(.typingSessionCount)

        leftClicks = try i(.leftClicks)
        rightClicks = try i(.rightClicks)
        doubleClicks = try i(.doubleClicks)
        dragCount = try i(.dragCount)
        clicksPerMinute = Self.normalizedInts(try c.decodeIfPresent([Int].self, forKey: .clicksPerMinute))
        cursorDistancePixels = try d(.cursorDistancePixels)
        maxCursorSpeedPxPerSec = try d(.maxCursorSpeedPxPerSec)
        idleCursorSeconds = try i(.idleCursorSeconds)

        scrollUpPoints = try d(.scrollUpPoints)
        scrollDownPoints = try d(.scrollDownPoints)
        scrollHorizontalPoints = try d(.scrollHorizontalPoints)
        scrollDirectionChanges = try i(.scrollDirectionChanges)
        maxScrollSpeedPointsPerSec = try d(.maxScrollSpeedPointsPerSec)
        scrollPerMinute = Self.normalizedDoubles(try c.decodeIfPresent([Double].self, forKey: .scrollPerMinute))

        activityPerMinute = Self.normalizedInts(try c.decodeIfPresent([Int].self, forKey: .activityPerMinute))

        clipboardCopyCount = try i(.clipboardCopyCount)
        clipboardPasteCount = try i(.clipboardPasteCount)
        clipboardCutCount = try i(.clipboardCutCount)
        clipboardTypeCounts = try c.decodeIfPresent([String: Int].self, forKey: .clipboardTypeCounts) ?? [:]

        appSessions = try c.decodeIfPresent([AppSessionRecord].self, forKey: .appSessions) ?? []
        totalAppSwitches = try i(.totalAppSwitches)
        shortDwellCount = try i(.shortDwellCount)
        appLaunchCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLaunchCounts) ?? [:]
        appTerminateCounts = try c.decodeIfPresent([String: Int].self, forKey: .appTerminateCounts) ?? [:]
        appKeyPresses = try c.decodeIfPresent([String: Int].self, forKey: .appKeyPresses) ?? [:]
        appClicks = try c.decodeIfPresent([String: Int].self, forKey: .appClicks) ?? [:]
        appScrollPoints = try c.decodeIfPresent([String: Double].self, forKey: .appScrollPoints) ?? [:]
        appNames = try c.decodeIfPresent([String: String].self, forKey: .appNames) ?? [:]

        focusSessions = try c.decodeIfPresent([FocusSessionRecord].self, forKey: .focusSessions) ?? []
        focusInterruptionsByApp = try c.decodeIfPresent([String: Int].self, forKey: .focusInterruptionsByApp) ?? [:]

        firstActivity = try c.decodeIfPresent(Date.self, forKey: .firstActivity)
        lastActivity = try c.decodeIfPresent(Date.self, forKey: .lastActivity)
        activeSeconds = try i(.activeSeconds)
        activitySessions = try c.decodeIfPresent([ActivitySessionRecord].self, forKey: .activitySessions) ?? []

        sleepWakeEvents = try c.decodeIfPresent([SleepWakeRecord].self, forKey: .sleepWakeEvents) ?? []
        lockCount = try i(.lockCount)
        unlockCount = try i(.unlockCount)
        chargerConnectCount = try i(.chargerConnectCount)
        chargerDisconnectCount = try i(.chargerDisconnectCount)
        batterySamples = try c.decodeIfPresent([BatterySample].self, forKey: .batterySamples) ?? []

        chargeSessions = try c.decodeIfPresent([ChargeSessionRecord].self, forKey: .chargeSessions) ?? []
        secondsOnBattery = try i(.secondsOnBattery)
        secondsOnAC = try i(.secondsOnAC)
        lowPowerModeSeconds = try i(.lowPowerModeSeconds)
        elevatedThermalSeconds = try i(.elevatedThermalSeconds)

        lidCloseCount = try i(.lidCloseCount)
        lidOpenCount = try i(.lidOpenCount)
        lidClosedSeconds = try i(.lidClosedSeconds)

        externalDisplayConnectCount = try i(.externalDisplayConnectCount)
        externalDisplayDisconnectCount = try i(.externalDisplayDisconnectCount)
        maxSimultaneousDisplays = try i(.maxSimultaneousDisplays)
        audioOutputDeviceChangeCount = try i(.audioOutputDeviceChangeCount)
        displaySleepCount = try i(.displaySleepCount)
        displayWakeCount = try i(.displayWakeCount)
        screenOnSeconds = try i(.screenOnSeconds)
        dragDistancePoints = try d(.dragDistancePoints)
        networkDownloadBytes = try c.decodeIfPresent(UInt64.self, forKey: .networkDownloadBytes) ?? 0
        networkUploadBytes = try c.decodeIfPresent(UInt64.self, forKey: .networkUploadBytes) ?? 0
        peakDownloadBytesPerSec = try d(.peakDownloadBytesPerSec)
        peakUploadBytesPerSec = try d(.peakUploadBytesPerSec)
    }

    /// Per-minute arrays must always be exactly 1440 long — a short or over-long array from an
    /// older/corrupt record would otherwise crash the index-based writes in `ActivityCenter`.
    private static func normalizedInts(_ values: [Int]?) -> [Int] {
        normalize(values, zero: 0)
    }

    private static func normalizedDoubles(_ values: [Double]?) -> [Double] {
        normalize(values, zero: 0)
    }

    private static func normalize<T>(_ values: [T]?, zero: T) -> [T] {
        guard var values, !values.isEmpty else {
            return Array(repeating: zero, count: minutesPerDay)
        }
        if values.count < minutesPerDay {
            values.append(contentsOf: Array(repeating: zero, count: minutesPerDay - values.count))
        } else if values.count > minutesPerDay {
            values = Array(values.prefix(minutesPerDay))
        }
        return values
    }
}
