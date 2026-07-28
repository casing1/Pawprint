import Foundation

/// What counts as a streak, in one place.
///
/// The streak decides the cat's collar, so it is asked twice from opposite directions: the Today
/// tab wants "how long is my streak right now", and the gallery wants "how long was it on the 14th
/// of March". Those were answered by two different pieces of code that disagreed — the gallery
/// simply passed `0` for every day that wasn't today, so a cat that had earned a gold collar was
/// redrawn bare the moment the date rolled over. Nothing about the collar was lost; it was never
/// asked for.
///
/// Both answers come from here now, so they cannot drift apart again.
enum StreakRule {

    /// A day counts when something was actually recorded on it.
    ///
    /// A row can exist for a day the Mac was merely switched on, so the presence of a row is not
    /// enough — that would let an untouched day extend a streak.
    static func isActive(_ raw: DailyRawCounters) -> Bool {
        raw.activeSeconds > 0 || raw.totalKeyPresses > 0
    }

    static func isActive(_ summary: DailySummary) -> Bool {
        summary.activeSeconds > 0 || summary.totalKeyPresses > 0
    }

    /// Consecutive active days ending on `day`, looking each one up as it goes.
    ///
    /// Stops at the first gap, so the cost is the length of the streak and not the length of the
    /// history. `isActive` is a closure because the caller may already hold the days in memory.
    static func streak(endingOn day: String, isActive: (String) -> Bool) -> Int {
        var count = 0
        var cursor = day
        while isActive(cursor) {
            count += 1
            cursor = DayKey.addingDays(-1, to: cursor)
        }
        return count
    }

    /// The streak on every day in `summaries`, in one pass.
    ///
    /// The gallery draws hundreds of cats and filters and sorts them by traits derived from this,
    /// so walking backwards per cat would be quadratic. Walking forwards once is not.
    static func streaks(for summaries: [DailySummary]) -> [String: Int] {
        let active = Set(summaries.filter(isActive).map(\.day))
        var result: [String: Int] = [:]
        for day in active.sorted() {
            result[day] = (result[DayKey.addingDays(-1, to: day)] ?? 0) + 1
        }
        return result
    }
}
