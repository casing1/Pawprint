import Foundation

/// Everything the app asks of storage.
///
/// Introduced so the layers above stop naming SQLite. `ActivityCenter` reached for
/// `PawprintStore.shared` in its initialiser, which meant that testing anything it does — a day
/// rolling over, a session being split, a setting being applied — required the real database in
/// the real Application Support directory, and left whatever it wrote behind.
///
/// The shape is deliberately the one that already existed: whole days in and out, keyed by day
/// string. It suits how the data is used and the format is not what needed changing.
package protocol ActivityStore: AnyObject {
    func loadDay(_ day: String) -> DailyRawCounters?
    func loadDays(from startDay: String, to endDay: String) -> [DailyRawCounters]
    func allDays() -> [DailyRawCounters]
    func saveDay(_ counters: DailyRawCounters)
    func deleteDay(_ day: String)
    func deleteDays(before day: String)
    func deleteAll()

    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)

    func loadUnlockedAchievements() -> [UnlockedAchievement]
    func saveUnlockedAchievements(_ achievements: [UnlockedAchievement])
}

extension PawprintStore: ActivityStore {}

/// A store that keeps everything in memory.
///
/// For tests, and only for tests: it is the difference between "does a day roll over correctly"
/// being a question you can ask in a millisecond and one that needs a real database on disk.
package final class InMemoryActivityStore: ActivityStore {
    private var days: [String: DailyRawCounters] = [:]
    private var settings = AppSettings()
    private var achievements: [UnlockedAchievement] = []

    /// Counts every write, so a test can assert that something was persisted rather than assuming.
    package private(set) var saveCount = 0

    package init(days: [DailyRawCounters] = [], settings: AppSettings = AppSettings()) {
        for day in days { self.days[day.day] = day }
        self.settings = settings
    }

    package func loadDay(_ day: String) -> DailyRawCounters? { days[day] }

    package func loadDays(from startDay: String, to endDay: String) -> [DailyRawCounters] {
        days.values.filter { $0.day >= startDay && $0.day <= endDay }.sorted { $0.day < $1.day }
    }

    package func allDays() -> [DailyRawCounters] {
        days.values.sorted { $0.day < $1.day }
    }

    package func saveDay(_ counters: DailyRawCounters) {
        days[counters.day] = counters
        saveCount += 1
    }

    package func deleteDay(_ day: String) { days[day] = nil }

    package func deleteDays(before day: String) {
        for key in days.keys where key < day { days[key] = nil }
    }

    package func deleteAll() {
        days.removeAll()
        achievements.removeAll()
    }

    package func loadSettings() -> AppSettings { settings }
    package func saveSettings(_ settings: AppSettings) { self.settings = settings }

    package func loadUnlockedAchievements() -> [UnlockedAchievement] { achievements }
    package func saveUnlockedAchievements(_ achievements: [UnlockedAchievement]) {
        self.achievements = achievements
    }
}
