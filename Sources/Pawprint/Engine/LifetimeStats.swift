import Foundation

/// All-time totals across every recorded day. These are what the level system progresses
/// against — unlike daily numbers they only ever grow, so there's always a next milestone.
struct LifetimeStats {
    var daysRecorded: Int = 0
    var firstDay: String?
    var lastDay: String?

    var totalKeyPresses: Int = 0
    var characterKeyPresses: Int = 0
    var totalClicks: Int = 0
    var totalAppSwitches: Int = 0
    var cursorDistanceMeters: Double = 0
    var scrollScreens: Double = 0
    var totalFocusSeconds: Int = 0
    var totalActiveSeconds: Int = 0
    var totalScreenOnSeconds: Int = 0
    var clipboardCopyCount: Int = 0
    var clipboardPasteCount: Int = 0
    var shortcutTotal: Int = 0
    var sleepCount: Int = 0
    var batteryDrainedPercent: Int = 0
    var networkDownloadBytes: UInt64 = 0
    var networkUploadBytes: UInt64 = 0

    // All-time bests
    var bestWPM: Double = 0
    var bestWPMDay: String?
    var bestKeysInDay: Int = 0
    var bestKeysDay: String?
    var bestFocusSeconds: Int = 0
    var bestFocusDay: String?
    var bestActiveSeconds: Int = 0
    var bestActiveDay: String?
    var bestScoreTotal: Int = 0
    var bestScoreDay: String?

    /// Day-of-week distribution of active time, index 0 = Sunday. Used for the "무슨 요일에
    /// 가장 바쁜가" insight.
    var activeSecondsByWeekday: [Int] = Array(repeating: 0, count: 7)

    var totalEnergyWattHours: Double? {
        BatteryHardware.shared.wattHours(fromPercent: batteryDrainedPercent)
    }

    var busiestWeekday: Int? {
        guard let peak = activeSecondsByWeekday.enumerated().max(by: { $0.element < $1.element }),
              peak.element > 0 else { return nil }
        return peak.offset
    }

    static func build(from summaries: [DailySummary]) -> LifetimeStats {
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
}
