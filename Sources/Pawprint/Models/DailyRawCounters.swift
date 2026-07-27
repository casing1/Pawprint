import Foundation

/// One activation period of a single app. `appName` is the human-readable name;
/// never any window title, document name, or URL is captured.
struct AppSessionRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var bundleID: String
    var appName: String
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// A stretch of continuous work inside one app (or a small cluster of related apps).
struct FocusSessionRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var start: Date
    var end: Date
    var primaryApp: String
    var interruptionCount: Int = 0

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// A stretch of continuous activity separated from neighboring activity by an idle gap.
struct ActivitySessionRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct SleepWakeRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: MacStateEventType
    var timestamp: Date
    var durationSeconds: Int = 0
}

struct BatterySample: Codable, Hashable {
    var timestamp: Date
    var level: Int
    var isCharging: Bool
}

/// One plugged-in period, from charger connect to disconnect.
struct ChargeSessionRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var start: Date
    var end: Date?
    var startLevel: Int
    var endLevel: Int?

    var gainedPercent: Int? {
        guard let endLevel else { return nil }
        return max(0, endLevel - startLevel)
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
struct DailyRawCounters: Codable {
    static let minutesPerDay = 24 * 60

    var day: String

    // MARK: Keyboard
    var totalKeyPresses: Int = 0
    var characterKeyPresses: Int = 0
    var keyCategoryCounts: [String: Int] = [:]
    var shortcutCounts: [String: Int] = [:]
    /// Press count per physical key, keyed by macOS virtual key code. This is an unordered
    /// frequency table for the heatmap — it records *which key on the board* was pressed and how
    /// often, never the sequence and never the character produced (which depends on layout,
    /// modifiers, and IME state that Pawprint deliberately doesn't read).
    var keyCodeCounts: [String: Int] = [:]
    /// Character-key presses bucketed by minute-of-day (0...1439). Used for WPM-over-time only —
    /// no key identity or order is retained, just a count per minute.
    var charKeysPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)
    var maxWPM: Double = 0
    var maxWPMMinute: Int? = nil
    var longestTypingStreakSeconds: Int = 0
    var typingSessionCount: Int = 0

    // MARK: Mouse / trackpad
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var doubleClicks: Int = 0
    var dragCount: Int = 0
    var clicksPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)
    var cursorDistancePixels: Double = 0
    var maxCursorSpeedPxPerSec: Double = 0
    var idleCursorSeconds: Int = 0

    /// Scroll distance in **points**, normalized across input devices.
    ///
    /// `NSEvent.scrollingDeltaY` is in points for precise devices (trackpad, Magic Mouse) but in
    /// *lines* for classic notched wheels; treating both as lines over-counted trackpad scrolling
    /// by more than an order of magnitude. `MouseMonitor` now converts line-based deltas to
    /// points before accumulating here.
    var scrollUpPoints: Double = 0
    var scrollDownPoints: Double = 0
    var scrollHorizontalPoints: Double = 0
    var scrollDirectionChanges: Int = 0
    var maxScrollSpeedPointsPerSec: Double = 0
    var scrollPerMinute: [Double] = Array(repeating: 0, count: minutesPerDay)

    /// Combined keyboard+mouse intensity per minute, drives the "오늘" mini timeline sparkline.
    var activityPerMinute: [Int] = Array(repeating: 0, count: minutesPerDay)

    // MARK: Clipboard
    var clipboardCopyCount: Int = 0
    var clipboardPasteCount: Int = 0
    var clipboardCutCount: Int = 0
    var clipboardTypeCounts: [String: Int] = [:]

    // MARK: App usage
    var appSessions: [AppSessionRecord] = []
    var totalAppSwitches: Int = 0
    var shortDwellCount: Int = 0
    var appLaunchCounts: [String: Int] = [:]
    var appTerminateCounts: [String: Int] = [:]

    /// Input attributed to whichever app was frontmost at the time, keyed by bundle id.
    /// Counts only — never which keys, in what order, or what was clicked on. Excluded apps are
    /// filtered upstream, so nothing is attributed to them.
    var appKeyPresses: [String: Int] = [:]
    var appClicks: [String: Int] = [:]
    var appScrollPoints: [String: Double] = [:]
    /// Display names for the bundle ids above, so history stays readable if an app is uninstalled.
    var appNames: [String: String] = [:]

    // MARK: Focus
    var focusSessions: [FocusSessionRecord] = []
    var focusInterruptionsByApp: [String: Int] = [:]

    // MARK: Active / idle time
    var firstActivity: Date? = nil
    var lastActivity: Date? = nil
    var activeSeconds: Int = 0
    var activitySessions: [ActivitySessionRecord] = []

    // MARK: Mac state
    var sleepWakeEvents: [SleepWakeRecord] = []
    var lockCount: Int = 0
    var unlockCount: Int = 0
    var chargerConnectCount: Int = 0
    var chargerDisconnectCount: Int = 0
    var batterySamples: [BatterySample] = []

    // MARK: Power detail
    var chargeSessions: [ChargeSessionRecord] = []
    var secondsOnBattery: Int = 0
    var secondsOnAC: Int = 0
    var lowPowerModeSeconds: Int = 0
    /// Seconds spent in a thermal state above `.nominal`.
    var elevatedThermalSeconds: Int = 0

    // MARK: Lid (clamshell)
    var lidCloseCount: Int = 0
    var lidOpenCount: Int = 0
    var lidClosedSeconds: Int = 0

    // MARK: Displays & audio
    var externalDisplayConnectCount: Int = 0
    var externalDisplayDisconnectCount: Int = 0
    var maxSimultaneousDisplays: Int = 0
    var audioOutputDeviceChangeCount: Int = 0
    var displaySleepCount: Int = 0
    var displayWakeCount: Int = 0
    /// Wall-clock seconds the display was actually lit — distinct from `activeSeconds`, which
    /// only counts stretches with real input. The gap between them is "screen on, but idle".
    var screenOnSeconds: Int = 0

    // MARK: Extra pointer detail
    var dragDistancePoints: Double = 0

    // MARK: Network
    /// Bytes transferred across physical network interfaces. Totals only — no hosts, ports,
    /// or contents are ever observed.
    var networkDownloadBytes: UInt64 = 0
    var networkUploadBytes: UInt64 = 0
    var peakDownloadBytesPerSec: Double = 0
    var peakUploadBytesPerSec: Double = 0

    init(day: String) {
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

    init(from decoder: Decoder) throws {
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
