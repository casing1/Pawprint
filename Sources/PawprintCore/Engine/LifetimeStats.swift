import Foundation

/// All-time totals across every recorded day. These are what the level system progresses
/// against — unlike daily numbers they only ever grow, so there's always a next milestone.
package struct LifetimeStats {
    package var daysRecorded: Int = 0
    package var firstDay: String?
    package var lastDay: String?

    package var totalKeyPresses: Int = 0
    package var characterKeyPresses: Int = 0
    package var totalClicks: Int = 0
    package var totalAppSwitches: Int = 0
    package var cursorDistanceMeters: Double = 0
    package var scrollScreens: Double = 0
    package var totalFocusSeconds: Int = 0
    package var totalActiveSeconds: Int = 0
    package var totalScreenOnSeconds: Int = 0
    package var clipboardCopyCount: Int = 0
    package var clipboardPasteCount: Int = 0
    package var shortcutTotal: Int = 0
    package var sleepCount: Int = 0
    package var batteryDrainedPercent: Int = 0
    package var networkDownloadBytes: UInt64 = 0
    package var networkUploadBytes: UInt64 = 0

    // All-time bests
    package var bestWPM: Double = 0
    package var bestWPMDay: String?
    package var bestKeysInDay: Int = 0
    package var bestKeysDay: String?
    package var bestFocusSeconds: Int = 0
    package var bestFocusDay: String?
    package var bestActiveSeconds: Int = 0
    package var bestActiveDay: String?
    package var bestScoreTotal: Int = 0
    package var bestScoreDay: String?

    /// Day-of-week distribution of active time, index 0 = Sunday. Used for the "무슨 요일에
    /// 가장 바쁜가" insight.
    package var activeSecondsByWeekday: [Int] = Array(repeating: 0, count: 7)

    /// Still a lookup rather than a parameter, unlike the summary's — a lifetime total is read
    /// straight from a view and threading the machine through every reader would cost more than it
    /// buys. It goes through `MachineFacts` so there is one place the battery is asked.
    package var totalEnergyWattHours: Double? {
        MachineFacts.current.wattHours(fromPercent: batteryDrainedPercent)
    }

    package var busiestWeekday: Int? {
        guard let peak = activeSecondsByWeekday.enumerated().max(by: { $0.element < $1.element }),
              peak.element > 0 else { return nil }
        return peak.offset
    }

    static package func build(from summaries: [DailySummary]) -> LifetimeStats {
        var stats = LifetimeStats()
        let calendar = Calendar.current

        // A day with no activity at all shouldn't count toward "days recorded" — an empty row
        // can exist just because the app was launched.
        let meaningful = summaries.filter { $0.activeSeconds > 0 || $0.totalKeyPresses > 0 }

        stats.daysRecorded = meaningful.count
        stats.firstDay = meaningful.first?.day
        stats.lastDay = meaningful.last?.day

        for s in meaningful {
            stats.totalKeyPresses += s.totalKeyPresses
            stats.characterKeyPresses += s.characterKeyPresses
            stats.totalClicks += s.totalClicks
            stats.totalAppSwitches += s.totalAppSwitches
            stats.cursorDistanceMeters += s.cursorDistanceMeters
            stats.scrollScreens += s.scrollScreens
            stats.totalFocusSeconds += s.totalFocusSeconds
            stats.totalActiveSeconds += s.activeSeconds
            stats.totalScreenOnSeconds += s.screenOnSeconds
            stats.clipboardCopyCount += s.clipboardCopyCount
            stats.clipboardPasteCount += s.clipboardPasteCount
            stats.shortcutTotal += s.shortcutCounts.values.reduce(0, +)
            stats.sleepCount += s.sleepCount
            stats.batteryDrainedPercent += s.batteryDrainedPercent
            stats.networkDownloadBytes += s.networkDownloadBytes
            stats.networkUploadBytes += s.networkUploadBytes

            if s.maxWPM > stats.bestWPM {
                stats.bestWPM = s.maxWPM
                stats.bestWPMDay = s.day
            }
            if s.totalKeyPresses > stats.bestKeysInDay {
                stats.bestKeysInDay = s.totalKeyPresses
                stats.bestKeysDay = s.day
            }
            if s.longestFocusSeconds > stats.bestFocusSeconds {
                stats.bestFocusSeconds = s.longestFocusSeconds
                stats.bestFocusDay = s.day
            }
            if s.activeSeconds > stats.bestActiveSeconds {
                stats.bestActiveSeconds = s.activeSeconds
                stats.bestActiveDay = s.day
            }
            if let score = s.score, score.total > stats.bestScoreTotal {
                stats.bestScoreTotal = score.total
                stats.bestScoreDay = s.day
            }

            if let date = DayKey.date(fromDayString: s.day) {
                let weekday = calendar.component(.weekday, from: date) - 1
                if weekday >= 0 && weekday < 7 {
                    stats.activeSecondsByWeekday[weekday] += s.activeSeconds
                }
            }
        }

        return stats
    }
    /// The memberwise initializer, at package access — a `package struct`
    /// otherwise gets an internal one the application target cannot reach.
    package init(daysRecorded: Int = 0,
                 firstDay: String? = nil,
                 lastDay: String? = nil,
                 totalKeyPresses: Int = 0,
                 characterKeyPresses: Int = 0,
                 totalClicks: Int = 0,
                 totalAppSwitches: Int = 0,
                 cursorDistanceMeters: Double = 0,
                 scrollScreens: Double = 0,
                 totalFocusSeconds: Int = 0,
                 totalActiveSeconds: Int = 0,
                 totalScreenOnSeconds: Int = 0,
                 clipboardCopyCount: Int = 0,
                 clipboardPasteCount: Int = 0,
                 shortcutTotal: Int = 0,
                 sleepCount: Int = 0,
                 batteryDrainedPercent: Int = 0,
                 networkDownloadBytes: UInt64 = 0,
                 networkUploadBytes: UInt64 = 0,
                 bestWPM: Double = 0,
                 bestWPMDay: String? = nil,
                 bestKeysInDay: Int = 0,
                 bestKeysDay: String? = nil,
                 bestFocusSeconds: Int = 0,
                 bestFocusDay: String? = nil,
                 bestActiveSeconds: Int = 0,
                 bestActiveDay: String? = nil,
                 bestScoreTotal: Int = 0,
                 bestScoreDay: String? = nil,
                 activeSecondsByWeekday: [Int] = Array(repeating: 0, count: 7)) {
        self.daysRecorded = daysRecorded
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.totalKeyPresses = totalKeyPresses
        self.characterKeyPresses = characterKeyPresses
        self.totalClicks = totalClicks
        self.totalAppSwitches = totalAppSwitches
        self.cursorDistanceMeters = cursorDistanceMeters
        self.scrollScreens = scrollScreens
        self.totalFocusSeconds = totalFocusSeconds
        self.totalActiveSeconds = totalActiveSeconds
        self.totalScreenOnSeconds = totalScreenOnSeconds
        self.clipboardCopyCount = clipboardCopyCount
        self.clipboardPasteCount = clipboardPasteCount
        self.shortcutTotal = shortcutTotal
        self.sleepCount = sleepCount
        self.batteryDrainedPercent = batteryDrainedPercent
        self.networkDownloadBytes = networkDownloadBytes
        self.networkUploadBytes = networkUploadBytes
        self.bestWPM = bestWPM
        self.bestWPMDay = bestWPMDay
        self.bestKeysInDay = bestKeysInDay
        self.bestKeysDay = bestKeysDay
        self.bestFocusSeconds = bestFocusSeconds
        self.bestFocusDay = bestFocusDay
        self.bestActiveSeconds = bestActiveSeconds
        self.bestActiveDay = bestActiveDay
        self.bestScoreTotal = bestScoreTotal
        self.bestScoreDay = bestScoreDay
        self.activeSecondsByWeekday = activeSecondsByWeekday
    }

}
