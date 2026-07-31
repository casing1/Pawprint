import XCTest
import PawprintCore
@testable import Pawprint

/// What the store does when the disk does not cooperate.
///
/// Every call in `PawprintStore` used to be `try?`. A failed write returned nothing and looked
/// exactly like a successful one, so a full disk or a permissions change cost the user their day in
/// silence — the app kept counting and the numbers kept climbing on screen. These check the two
/// things that replaced it: the failure is recorded where the interface can see it, and the app
/// keeps running.
final class StoreFailureTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        StoreHealth.shared.reset()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pawprint-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        StoreHealth.shared.reset()
    }

    private func store(_ name: String = "records.sqlite3") -> PawprintStore {
        PawprintStore(url: directory.appendingPathComponent(name))
    }

    // MARK: - The happy path still works

    func testAFreshStoreOpensCleanAndReportsNoFailure() {
        let store = store()
        XCTAssertFalse(store.isDegraded)
        XCTAssertNil(StoreHealth.shared.lastFailure)

        var day = DailyRawCounters(day: "2026-07-31")
        day.totalKeyPresses = 42
        store.saveDay(day)
        XCTAssertEqual(store.loadDay("2026-07-31")?.totalKeyPresses, 42)
        XCTAssertNil(StoreHealth.shared.lastFailure)
    }

    // MARK: - Opening

    /// An unopenable file must not stop the app from launching. It used to `fatalError`, which
    /// turned an unwritable disk into an app that would not start — and therefore into no screen on
    /// which to explain why.
    func testAnUnopenableFileDegradesInsteadOfCrashing() throws {
        // A directory where the database should be: sqlite cannot open it, and never will.
        let path = directory.appendingPathComponent("blocked.sqlite3")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

        let store = PawprintStore(url: path)
        XCTAssertTrue(store.isDegraded, "the store claimed a directory was a database")
        XCTAssertEqual(StoreHealth.shared.lastFailure.map { if case .couldNotOpen = $0 { true } else { false } },
                       true)

        // Degraded still means usable: today is counted and shown, just not kept.
        var day = DailyRawCounters(day: "2026-07-31")
        day.totalKeyPresses = 7
        store.saveDay(day)
        XCTAssertEqual(store.loadDay("2026-07-31")?.totalKeyPresses, 7)
    }

    // MARK: - Schema version

    /// A fresh file is stamped, so the next migration knows where it is starting from.
    func testANewFileIsStampedWithTheSchemaVersion() throws {
        let url = directory.appendingPathComponent("stamped.sqlite3")
        _ = PawprintStore(url: url)

        let db = try SQLiteDatabase(path: url.path)
        var version = -1
        try db.query("PRAGMA user_version;") { row in version = row.columnInt(0) }
        XCTAssertEqual(version, PawprintStore.schemaVersion)
    }

    /// Every file in the wild is version 0 — written before there was a version. Opening one must
    /// stamp it, keep every row, and leave a copy behind.
    func testAnUnversionedFileIsMigratedAndBackedUpFirst() throws {
        let url = directory.appendingPathComponent("legacy.sqlite3")
        let raw = try SQLiteDatabase(path: url.path)
        try raw.exec("""
            CREATE TABLE daily_stats (day TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL);
        """)
        try raw.exec("""
            INSERT INTO daily_stats VALUES ('2025-05-05', '{"day":"2025-05-05","totalKeyPresses":99}', 0);
        """)
        try raw.exec("PRAGMA user_version = 0;")

        let store = PawprintStore(url: url)
        XCTAssertEqual(store.loadDay("2025-05-05")?.totalKeyPresses, 99, "migration lost a day")
        XCTAssertNil(StoreHealth.shared.lastFailure)

        let backup = url.deletingPathExtension().appendingPathExtension("v0.backup.sqlite3")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path),
                      "no copy was taken before migrating")
    }

    /// A file from a future build. The format is additive, so it is read rather than refused —
    /// refusing would strand anyone who downgraded.
    func testAFileFromANewerBuildIsStillRead() throws {
        let url = directory.appendingPathComponent("future.sqlite3")
        let raw = try SQLiteDatabase(path: url.path)
        try raw.exec("""
            CREATE TABLE daily_stats (day TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL);
        """)
        try raw.exec("""
            INSERT INTO daily_stats VALUES ('2027-01-01', '{"day":"2027-01-01","totalKeyPresses":5}', 0);
        """)
        try raw.exec("PRAGMA user_version = 99;")

        let store = PawprintStore(url: url)
        XCTAssertEqual(store.loadDay("2027-01-01")?.totalKeyPresses, 5)
        XCTAssertNil(StoreHealth.shared.lastFailure, "a newer file is not a failure")
    }

    // MARK: - Corrupt rows

    /// One unreadable row costs that row. The health record is untouched, because a day written by
    /// a build that no longer exists is not something the user can act on.
    func testAnUnreadableRowIsSkippedAndTheRestSurvive() throws {
        let url = directory.appendingPathComponent("mixed.sqlite3")
        _ = PawprintStore(url: url)
        let raw = try SQLiteDatabase(path: url.path)
        try raw.exec("INSERT INTO daily_stats VALUES ('2026-01-01', '{\"day\":\"2026-01-01\"}', 0);")
        try raw.exec("INSERT INTO daily_stats VALUES ('2026-01-02', 'not json at all', 0);")
        try raw.exec("INSERT INTO daily_stats VALUES ('2026-01-03', '{\"day\":\"2026-01-03\"}', 0);")

        let store = PawprintStore(url: url)
        XCTAssertEqual(store.allDays().map(\.day), ["2026-01-01", "2026-01-03"])
        XCTAssertNil(store.loadDay("2026-01-02"))
        XCTAssertEqual(store.loadDays(from: "2026-01-01", to: "2026-01-31").count, 2)
    }

    // MARK: - Health

    /// A failure clears once a write works again, so a transient problem does not leave a warning
    /// on screen for the rest of the session.
    func testASuccessfulWriteClearsAPreviousFailure() {
        StoreHealth.shared.record(.couldNotSaveDay(day: "2026-07-31", reason: "disk full"))
        XCTAssertNotNil(StoreHealth.shared.lastFailure)

        store().saveDay(DailyRawCounters(day: "2026-07-31"))
        XCTAssertNil(StoreHealth.shared.lastFailure, "the warning outlived the problem")
    }

    /// The count does not clear, so "it happened once an hour ago" and "it is still happening" stay
    /// distinguishable.
    func testTheFailureCountIsCumulative() {
        StoreHealth.shared.record(.couldNotRead("a"))
        StoreHealth.shared.record(.couldNotRead("b"))
        XCTAssertEqual(StoreHealth.shared.count, 2)
        StoreHealth.shared.recordSuccess()
        XCTAssertEqual(StoreHealth.shared.count, 2)
        XCTAssertNil(StoreHealth.shared.lastFailure)
    }

    /// What the user is shown must be a sentence in their language, not a hash and not SQLite's
    /// wording.
    ///
    /// The packs are loaded from the repository first: `swift test` runs in a bundle that carries
    /// none, so without this every lookup would hand back its own key and the check would be
    /// unfailable.
    func testEveryFailureHasSomethingToSayInEveryLanguage() throws {
        let packs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Pawprint/Resources/Localization")

        let failures: [StoreFailure] = [
            .couldNotOpen("x"),
            .couldNotSaveDay(day: "2026-07-31", reason: "x"),
            .couldNotSaveSettings("x"),
            .couldNotRead("x"),
            .migrationFailed(from: 0, to: 1, reason: "x"),
        ]

        for code in AppLanguage.availableCodes {
            let data = try Data(contentsOf: packs.appendingPathComponent("\(code).json"))
            let table = try JSONDecoder().decode([String: String].self, from: data)
            Tables.setActive(table, code: code)
            defer { Tables.setActive([:], code: "") }

            for failure in failures {
                let message = failure.summary
                XCTAssertFalse(message.isEmpty, "\(code): \(failure) has no message")
                XCTAssertFalse(message.hasPrefix("storeHealth."),
                               "\(code): \(failure) shows a raw key")
                XCTAssertFalse(message.contains("SQLite"),
                               "\(code): \(failure) leaks the database's wording")
            }
        }
    }

    // MARK: - Retention

    func testDeletingBeforeADateKeepsThatDate() {
        let store = store()
        for day in ["2026-01-01", "2026-01-02", "2026-01-03"] {
            store.saveDay(DailyRawCounters(day: day))
        }
        store.deleteDays(before: "2026-01-02")
        XCTAssertEqual(store.allDays().map(\.day), ["2026-01-02", "2026-01-03"])
        XCTAssertNil(StoreHealth.shared.lastFailure)
    }
}
