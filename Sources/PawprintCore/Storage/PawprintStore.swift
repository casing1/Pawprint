import Foundation

/// Local persistence for Pawprint. Every day's raw counters are stored as one JSON blob in a
/// single-row-per-day table — simple, transactional, trivially supports "delete this date",
/// "delete everything before date X", and full export, without a sprawling relational schema.
///
/// Nothing here throws to its caller. A hundred SwiftUI call sites read a day to draw a number and
/// have nothing useful to do with an error, so the store swallows failures — but *loudly*: every
/// one is logged with `StoreLog` and recorded in `StoreHealth`, where the interface can show it.
/// It used to swallow them with `try?`, which made a full disk indistinguishable from a good day.
final package class PawprintStore {
    static package let shared = PawprintStore()

    private let db: SQLiteDatabase?
    package let databaseURL: URL

    /// True when the file could not be opened and the store is running on an in-memory database.
    ///
    /// The alternative was `fatalError`, which turned an unwritable disk into an application that
    /// would not launch — the worst possible response, because it also removes the only screen that
    /// could have explained why. Degraded means today is still counted and still shown; it is just
    /// not being kept.
    package private(set) var isDegraded = false

    /// Bumped when the schema changes. Stored in the file as `PRAGMA user_version`, so an older
    /// build opening a newer file can tell rather than guess.
    package static let schemaVersion = 1

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

    /// Where the running application keeps its records.
    ///
    /// Screenshots need a history that looks lived-in, and the only honest way to get one is to run
    /// the real app against a real database. `PAWPRINT_DB` points it at a throwaway file so the
    /// documentation can be captured without touching anyone's own records.
    package static func defaultURL() -> URL {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pawprint", isDirectory: true)
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        guard let override = ProcessInfo.processInfo.environment["PAWPRINT_DB"], !override.isEmpty else {
            return supportDir.appendingPathComponent("pawprint.sqlite3")
        }
        let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url
    }

    /// Opens a store at an arbitrary path.
    ///
    /// The application uses `shared`; this exists so a test can open a *file* rather than a
    /// dictionary. `InMemoryActivityStore` proves the callers behave, but only a real database
    /// proves that a blob written by an older build still comes back out.
    package init(url: URL = PawprintStore.defaultURL()) {
        self.databaseURL = url
        var opened: SQLiteDatabase?
        do {
            opened = try SQLiteDatabase(path: url.path)
        } catch {
            // Falling back rather than crashing. A read-only disk, a file owned by another user or
            // a database corrupted beyond opening should not stop the app from running.
            StoreHealth.shared.record(.couldNotOpen("\(error)"))
            isDegraded = true
            opened = try? SQLiteDatabase(path: ":memory:")
        }
        self.db = opened
        guard let db = opened else { return }
        do {
            try Self.migrate(db, backupOf: isDegraded ? nil : url)
            StoreLog.opened(at: url.path, schema: Self.schemaVersion)
        } catch {
            StoreHealth.shared.record(.migrationFailed(from: (try? Self.userVersion(db)) ?? -1,
                                                       to: Self.schemaVersion,
                                                       reason: "\(error)"))
        }
    }

    // MARK: - Schema

    private static func userVersion(_ db: SQLiteDatabase) throws -> Int {
        var version = 0
        try db.query("PRAGMA user_version;") { row in version = row.columnInt(0) }
        return version
    }

    /// Brings the file up to `schemaVersion`.
    ///
    /// Two rules. The whole migration runs in one transaction, so a failure half way leaves the
    /// file exactly as it was rather than half-converted. And a copy of the file is taken first,
    /// because a transaction protects against *this* migration failing and not against this
    /// migration being wrong — the backup is what makes a bad release recoverable.
    ///
    /// Version 0 is every file written before there was a version, which is every file in the wild.
    /// The schema is unchanged from it, so the migration is a stamp; the machinery exists so the
    /// next change has somewhere to go.
    private static func migrate(_ db: SQLiteDatabase, backupOf url: URL?) throws {
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

        let current = try userVersion(db)
        guard current < schemaVersion else {
            if current > schemaVersion {
                // An older build opening a newer file. The format is additive, so it will read
                // what it understands; saying so in the log beats a mystery later.
                StoreLog.info("file is schema v\(current), this build knows v\(schemaVersion)")
            }
            return
        }

        if let url { backUp(url, fromVersion: current) }

        try db.exec("BEGIN IMMEDIATE;")
        do {
            // v0 → v1: the schema above, which every existing file already has. Later versions add
            // their statements here, each guarded on `current`.
            try db.exec("PRAGMA user_version = \(schemaVersion);")
            try db.exec("COMMIT;")
            StoreLog.info("migrated schema v\(current) → v\(schemaVersion)")
        } catch {
            try? db.exec("ROLLBACK;")
            throw error
        }
    }

    /// A copy beside the database, kept until the next migration replaces it.
    private static func backUp(_ url: URL, fromVersion version: Int) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let backup = url.deletingPathExtension()
            .appendingPathExtension("v\(version).backup.sqlite3")
        do {
            if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
            try fm.copyItem(at: url, to: backup)
            StoreLog.info("backed up schema v\(version) before migrating")
        } catch {
            // Worth knowing about, not worth refusing to start over.
            StoreLog.report(.couldNotRead("backup before migration: \(error)"))
        }
    }

    // MARK: - Daily stats

    /// Decodes one row, charging a failure to that row alone.
    ///
    /// A day whose JSON cannot be read is lost, and that is unavoidable — but it must not take the
    /// query with it, or one bad write turns into an empty history.
    private static func decodeDay(_ row: OpaquePointer, day: String?) -> DailyRawCounters? {
        guard let json = row.columnText(0)?.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(DailyRawCounters.self, from: json)
        } catch {
            StoreLog.skippedRow(day: day ?? "unknown")
            return nil
        }
    }

    package func loadDay(_ day: String) -> DailyRawCounters? {
        var result: DailyRawCounters?
        read("SELECT data FROM daily_stats WHERE day = ? LIMIT 1;", [day]) { row in
            result = Self.decodeDay(row, day: day)
        }
        return result
    }

    package func loadDays(from startDay: String, to endDay: String) -> [DailyRawCounters] {
        var results: [DailyRawCounters] = []
        read("SELECT data, day FROM daily_stats WHERE day >= ? AND day <= ? ORDER BY day ASC;",
             [startDay, endDay]) { row in
            if let counters = Self.decodeDay(row, day: row.columnText(1)) { results.append(counters) }
        }
        return results
    }

    package func allDays() -> [DailyRawCounters] {
        var results: [DailyRawCounters] = []
        read("SELECT data, day FROM daily_stats ORDER BY day ASC;") { row in
            if let counters = Self.decodeDay(row, day: row.columnText(1)) { results.append(counters) }
        }
        return results
    }

    package func saveDay(_ counters: DailyRawCounters) {
        guard let json = try? Self.encoder.encode(counters),
              let jsonString = String(data: json, encoding: .utf8) else {
            StoreHealth.shared.record(.couldNotSaveDay(day: counters.day, reason: "could not encode"))
            return
        }
        let now = Int(Date().timeIntervalSince1970)
        write("""
            INSERT INTO daily_stats (day, data, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(day) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at;
        """, [counters.day, jsonString, now]) { reason in
            .couldNotSaveDay(day: counters.day, reason: reason)
        }
    }

    package func deleteDay(_ day: String) {
        write("DELETE FROM daily_stats WHERE day = ?;", [day]) { .couldNotSaveDay(day: day, reason: $0) }
    }

    package func deleteDays(before day: String) {
        write("DELETE FROM daily_stats WHERE day < ?;", [day]) { .couldNotSaveDay(day: day, reason: $0) }
    }

    package func deleteAll() {
        write("DELETE FROM daily_stats;") { .couldNotSaveDay(day: "all", reason: $0) }
    }

    // MARK: - Running a statement

    /// Runs a query, charging any failure to `StoreHealth` instead of discarding it.
    private func read(_ sql: String, _ bindings: [SQLiteBindable] = [],
                      _ rowHandler: (OpaquePointer) -> Void) {
        guard let db else { return }
        do {
            try db.query(sql, bindings, rowHandler)
        } catch {
            StoreHealth.shared.record(.couldNotRead("\(error)"))
        }
    }

    /// Runs a statement, reporting success so a transient failure clears the warning.
    private func write(_ sql: String, _ bindings: [SQLiteBindable] = [],
                       _ failure: (String) -> StoreFailure) {
        guard let db else {
            StoreHealth.shared.record(failure("no database"))
            return
        }
        do {
            _ = try db.run(sql, bindings)
            if !isDegraded { StoreHealth.shared.recordSuccess() }
        } catch {
            StoreHealth.shared.record(failure("\(error)"))
        }
    }

    /// One row per day with the headline metrics — far more useful than JSON for spreadsheets.
    /// Values are plain numbers so they can be charted directly; no app names are included, since
    /// a CSV is the format most likely to be shared onward.
    package func exportAllAsCSV(dayStartHour: Int) -> Data? {
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

    package func exportAllAsJSON() -> Data? {
        let all = allDays()
        return try? Self.encoder.encode(all)
    }

    // MARK: - Settings

    package func loadSettings() -> AppSettings {
        // The in-memory fallback has no copy of the user's privacy choices. Treating that empty
        // database as a fresh install would enable every tracker (and network update checks), even
        // when the unavailable file says they are paused or excluded. Keep the UI available, but
        // fail closed until persistent settings can be read again on a later launch.
        if isDegraded {
            var settings = AppSettings()
            settings.collectKeyboard = false
            settings.collectMouse = false
            settings.collectAppUsage = false
            settings.collectClipboard = false
            settings.collectSleepWake = false
            settings.collectPowerPeripherals = false
            settings.isPaused = true
            settings.updateCheckEnabled = false
            settings.updateCheckAutomatically = false
            return settings
        }

        var result: AppSettings?
        read("SELECT value FROM app_settings WHERE key = 'settings' LIMIT 1;") { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            do {
                result = try Self.decoder.decode(AppSettings.self, from: json)
            } catch {
                // Falling back to the defaults silently is how a user loses their exclusions and
                // their day-start hour without ever being told.
                StoreHealth.shared.record(.couldNotRead("settings: \(error)"))
            }
        }
        return result ?? AppSettings()
    }

    package func saveSettings(_ settings: AppSettings) {
        guard let json = try? Self.encoder.encode(settings),
              let jsonString = String(data: json, encoding: .utf8) else {
            StoreHealth.shared.record(.couldNotSaveSettings("could not encode"))
            return
        }
        write("""
            INSERT INTO app_settings (key, value) VALUES ('settings', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """, [jsonString]) { .couldNotSaveSettings($0) }
    }

    // MARK: - Adventure progression

    /// Adventure progression is stored in the same SQLite file as every other Pawprint record.
    ///
    /// The app target owns the schema of this JSON value; Core only provides the lifecycle-safe
    /// slot so exports, deletion, file permissions, and local-data documentation do not diverge
    /// across a second preferences file.
    package func loadAdventureProgressData() -> Data? {
        var result: Data?
        read("SELECT value FROM app_settings WHERE key = 'adventure_progress_v1' LIMIT 1;") { row in
            result = row.columnText(0)?.data(using: .utf8)
        }
        return result
    }

    package func saveAdventureProgressData(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            StoreHealth.shared.record(
                .couldNotSaveSettings("adventure progress: could not encode")
            )
            return
        }
        write("""
            INSERT INTO app_settings (key, value)
            VALUES ('adventure_progress_v1', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """, [jsonString]) {
            .couldNotSaveSettings("adventure progress: \($0)")
        }
    }

    package func deleteAdventureProgressData() {
        write("DELETE FROM app_settings WHERE key = 'adventure_progress_v1';") {
            .couldNotSaveSettings("delete adventure progress: \($0)")
        }
    }

    // MARK: - Achievements

    /// Stored in `app_settings` rather than alongside daily stats so that deleting a day's
    /// (or all) activity history never revokes a badge the user already earned.
    package func loadUnlockedAchievements() -> [UnlockedAchievement] {
        var result: [UnlockedAchievement] = []
        read("SELECT value FROM app_settings WHERE key = 'achievements' LIMIT 1;") { row in
            guard let json = row.columnText(0)?.data(using: .utf8) else { return }
            do {
                result = try Self.decoder.decode([UnlockedAchievement].self, from: json)
            } catch {
                StoreHealth.shared.record(.couldNotRead("achievements: \(error)"))
            }
        }
        return result
    }

    package func saveUnlockedAchievements(_ achievements: [UnlockedAchievement]) {
        guard let json = try? Self.encoder.encode(achievements),
              let jsonString = String(data: json, encoding: .utf8) else {
            StoreHealth.shared.record(.couldNotSaveSettings("achievements: could not encode"))
            return
        }
        write("""
            INSERT INTO app_settings (key, value) VALUES ('achievements', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """, [jsonString]) { .couldNotSaveSettings("achievements: \($0)") }
    }
}
