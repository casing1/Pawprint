import Foundation

/// Local persistence for Pawprint. Every day's raw counters are stored as one JSON blob in a
/// single-row-per-day table — simple, transactional, trivially supports "delete this date",
/// "delete everything before date X", and full export, without a sprawling relational schema.
final class PawprintStore {
    static let shared = PawprintStore()

    private let db: SQLiteDatabase
    let databaseURL: URL

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    private init() {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pawprint", isDirectory: true)
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let url = supportDir.appendingPathComponent("pawprint.sqlite3")
        self.databaseURL = url
        do {
            self.db = try SQLiteDatabase(path: url.path)
            try db.exec("""
                CREATE TABLE IF NOT EXISTS daily_stats (
                    day TEXT PRIMARY KEY,
                    data TEXT NOT NULL,
                    updated_at INTEGER NOT NULL
                );
            """)
            try db.exec("""
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
            """)
        } catch {
            fatalError("Pawprint could not open its local database: \(error)")
        }
    }

    // MARK: - Daily stats

    func loadDay(_ day: String) -> DailyRawCounters? {
        var result: DailyRawCounters?
        try? db.query("SELECT data FROM daily_stats WHERE day = ? LIMIT 1;", [day]) { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            result = try? Self.decoder.decode(DailyRawCounters.self, from: json)
        }
        return result
    }

    func loadDays(from startDay: String, to endDay: String) -> [DailyRawCounters] {
        var results: [DailyRawCounters] = []
        try? db.query(
            "SELECT data FROM daily_stats WHERE day >= ? AND day <= ? ORDER BY day ASC;",
            [startDay, endDay]
        ) { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            if let counters = try? Self.decoder.decode(DailyRawCounters.self, from: json) {
                results.append(counters)
            }
        }
        return results
    }

    func allDays() -> [DailyRawCounters] {
        var results: [DailyRawCounters] = []
        try? db.query("SELECT data FROM daily_stats ORDER BY day ASC;") { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            if let counters = try? Self.decoder.decode(DailyRawCounters.self, from: json) {
                results.append(counters)
            }
        }
        return results
    }

    func saveDay(_ counters: DailyRawCounters) {
        guard let json = try? Self.encoder.encode(counters),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        let now = Int(Date().timeIntervalSince1970)
        _ = try? db.run("""
            INSERT INTO daily_stats (day, data, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(day) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at;
        """, [counters.day, jsonString, now])
    }

    func deleteDay(_ day: String) {
        _ = try? db.run("DELETE FROM daily_stats WHERE day = ?;", [day])
    }

    func deleteDays(before day: String) {
        _ = try? db.run("DELETE FROM daily_stats WHERE day < ?;", [day])
    }

    func deleteAll() {
        _ = try? db.run("DELETE FROM daily_stats;")
    }

    /// One row per day with the headline metrics — far more useful than JSON for spreadsheets.
    /// Values are plain numbers so they can be charted directly; no app names are included, since
    /// a CSV is the format most likely to be shared onward.
    func exportAllAsCSV(dayStartHour: Int) -> Data? {
        let columns = [
            "date", "active_seconds", "screen_on_seconds", "focus_seconds", "longest_focus_seconds",
            "key_presses", "character_keys", "max_wpm", "clicks", "cursor_meters", "scroll_screens",
            "app_switches", "copies", "pastes", "battery_used_percent",
            "network_download_bytes", "network_upload_bytes", "score",
        ]
        var lines = [columns.joined(separator: ",")]

        for raw in allDays() {
            let s = StatsEngine.summary(for: raw, dayStartHour: dayStartHour)
            let row: [String] = [
                s.day,
                String(s.activeSeconds),
                String(s.screenOnSeconds),
                String(s.totalFocusSeconds),
                String(s.longestFocusSeconds),
                String(s.totalKeyPresses),
                String(s.characterKeyPresses),
                String(format: "%.1f", s.maxWPM),
                String(s.totalClicks),
                String(format: "%.1f", s.cursorDistanceMeters),
                String(format: "%.1f", s.scrollScreens),
                String(s.totalAppSwitches),
                String(s.clipboardCopyCount),
                String(s.clipboardPasteCount),
                String(s.batteryDrainedPercent),
                String(s.networkDownloadBytes),
                String(s.networkUploadBytes),
                String(s.score?.total ?? 0),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    func exportAllAsJSON() -> Data? {
        let all = allDays()
        return try? Self.encoder.encode(all)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        var result: AppSettings?
        try? db.query("SELECT value FROM app_settings WHERE key = 'settings' LIMIT 1;") { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            result = try? Self.decoder.decode(AppSettings.self, from: json)
        }
        return result ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        guard let json = try? Self.encoder.encode(settings),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        _ = try? db.run("""
            INSERT INTO app_settings (key, value) VALUES ('settings', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """, [jsonString])
    }

    // MARK: - Achievements

    /// Stored in `app_settings` rather than alongside daily stats so that deleting a day's
    /// (or all) activity history never revokes a badge the user already earned.
    func loadUnlockedAchievements() -> [UnlockedAchievement] {
        var result: [UnlockedAchievement] = []
        try? db.query("SELECT value FROM app_settings WHERE key = 'achievements' LIMIT 1;") { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            result = (try? Self.decoder.decode([UnlockedAchievement].self, from: json)) ?? []
        }
        return result
    }

    func saveUnlockedAchievements(_ achievements: [UnlockedAchievement]) {
        guard let json = try? Self.encoder.encode(achievements),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        _ = try? db.run("""
            INSERT INTO app_settings (key, value) VALUES ('achievements', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """, [jsonString])
    }
}
