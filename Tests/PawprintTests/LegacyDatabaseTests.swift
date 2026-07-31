import XCTest
import PawprintCore
@testable import Pawprint

/// Section F: today's build opening a database an older build wrote.
///
/// `StoredDataCompatibilityTests` holds the JSON shape; this holds everything around it — the SQL,
/// the `secondsSince1970` date strategy the store has always used, and what a row that cannot be
/// decoded costs. Those only exist once a real file is opened, and a dictionary standing in for a
/// database cannot show any of them.
///
/// The fixture is committed at `Fixtures/legacy-0.1.sqlite3` and holds three days: the oldest shape
/// in the wild, one from after the power fields arrived and before the network ones, and one row of
/// deliberate garbage.
final class LegacyDatabaseTests: XCTestCase {

    private static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/legacy-0.1.sqlite3")

    private var workingCopy: URL!

    /// Opened from a copy, always. A test that mutated the committed fixture would pass once.
    override func setUpWithError() throws {
        workingCopy = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pawprint-legacy-\(UUID().uuidString).sqlite3")
        try FileManager.default.copyItem(at: Self.fixture, to: workingCopy)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workingCopy)
    }

    private func store() -> PawprintStore { PawprintStore(url: workingCopy) }

    // MARK: - Opening

    /// Opening an old database must not migrate, rewrite or drop anything: the schema is
    /// `CREATE TABLE IF NOT EXISTS`, and the rows are the user's records.
    func testOpeningAnOldDatabaseLeavesItsRowsAlone() {
        let before = try! Data(contentsOf: workingCopy).count
        _ = store()
        let days = store().allDays()
        XCTAssertEqual(days.map(\.day), ["2025-11-04", "2025-12-19"])
        XCTAssertGreaterThan(before, 0)
    }

    // MARK: - The oldest shape

    func testTheOldestDayLoadsWithZeroesForEverythingAddedSince() {
        guard let day = store().loadDay("2025-11-04") else { return XCTFail("the oldest day did not load") }

        XCTAssertEqual(day.totalKeyPresses, 8421)
        XCTAssertEqual(day.characterKeyPresses, 6110)
        XCTAssertEqual(day.leftClicks, 733)
        XCTAssertEqual(day.rightClicks, 58)
        XCTAssertEqual(day.activeSeconds, 14_820)
        XCTAssertEqual(day.cursorDistancePixels, 412_300.5, accuracy: 0.001)

        // Added after this row was written. Zero, not a discarded day.
        XCTAssertEqual(day.screenOnSeconds, 0)
        XCTAssertEqual(day.networkDownloadBytes, 0)
        XCTAssertEqual(day.lidCloseCount, 0)
        XCTAssertEqual(day.scrollDirectionChanges, 0)
        XCTAssertTrue(day.focusSessions.isEmpty)
        XCTAssertTrue(day.batterySamples.isEmpty)
    }

    // MARK: - Dates

    /// Timestamps are stored as seconds since 1970 and must still decode as that. A change of
    /// strategy would not fail — it would silently read every stored date as some other instant.
    func testStoredTimestampsDecodeAsSecondsSince1970() {
        guard let day = store().loadDay("2025-12-19") else { return XCTFail("the middle day did not load") }

        XCTAssertEqual(day.sleepWakeEvents.count, 2)
        XCTAssertEqual(day.sleepWakeEvents[0].type, .sleep)
        XCTAssertEqual(day.sleepWakeEvents[0].timestamp,
                       Date(timeIntervalSince1970: 1_766_100_000))
        XCTAssertEqual(day.sleepWakeEvents[1].durationSeconds, 7_200)

        XCTAssertEqual(day.batterySamples.map(\.level), [96, 88])
        XCTAssertEqual(day.batterySamples[0].timestamp,
                       Date(timeIntervalSince1970: 1_766_090_000))

        XCTAssertEqual(day.chargeSessions.count, 1)
        XCTAssertEqual(day.chargeSessions[0].start, Date(timeIntervalSince1970: 1_766_094_000))
        XCTAssertEqual(day.chargeSessions[0].endLevel, 100)
        XCTAssertEqual(day.chargeSessions[0].gainedPercent, 12)
    }

    func testDictionaryCountersSurviveTheRoundTripThroughSQLite() {
        guard let day = store().loadDay("2025-12-19") else { return XCTFail("the middle day did not load") }
        XCTAssertEqual(day.keyCodeCounts["49"], 1_503)
        XCTAssertEqual(day.appKeyPresses["com.apple.dt.Xcode"], 9_800)
        XCTAssertEqual(day.maxWPM, 78.4, accuracy: 0.001)
        XCTAssertEqual(day.maxWPMMinute, 613)
    }

    // MARK: - Corruption

    /// One unreadable row costs exactly that row. The alternative — a decode failure taking down
    /// the whole query — would turn a single bad write into an empty history.
    func testOneUnreadableRowDoesNotTakeTheOthersWithIt() {
        let store = store()
        XCTAssertNil(store.loadDay("2025-12-20"), "the garbage row decoded")
        XCTAssertEqual(store.allDays().count, 2, "the garbage row cost more than itself")
        XCTAssertEqual(store.loadDays(from: "2025-01-01", to: "2026-12-31").map(\.day),
                       ["2025-11-04", "2025-12-19"])
    }

    // MARK: - Settings and achievements

    /// Settings written before half the keys existed must come back with today's defaults filled
    /// in and the user's own choices intact. A reset here silently discards an exclusion list.
    func testOldSettingsKeepTheirChoicesAndGainDefaults() {
        let settings = store().loadSettings()

        XCTAssertEqual(settings.dayStartHour, 5)
        XCTAssertEqual(settings.excludedApps.map(\.bundleID), ["com.apple.Passwords"])
        XCTAssertEqual(settings.retentionDays, 180)
        XCTAssertFalse(settings.isPaused)

        // Deliberately *not* restored. The focus threshold is the definition of a focus session,
        // so an old stored value would silently rewrite what every past day's focus figure meant —
        // those were computed against whatever it was at the time and are never recomputed. The
        // decoder reads the key and throws it away; five minutes is the answer for everyone.
        XCTAssertEqual(settings.focusThresholdSeconds, AppSettings.focusThresholdDefault)
        XCTAssertEqual(settings.focusThresholdSeconds, 300)

        // Never written by that build.
        XCTAssertEqual(settings.language, AppSettings().language)
        XCTAssertEqual(settings.collectSleepWake, AppSettings().collectSleepWake)
        XCTAssertEqual(settings.collectPowerPeripherals, AppSettings().collectPowerPeripherals)
    }

    /// Badges live in `app_settings` precisely so that clearing history cannot revoke one.
    func testAnEarnedBadgeSurvivesAndIsNotRevokedByClearingHistory() {
        let store = store()
        XCTAssertEqual(store.loadUnlockedAchievements().map(\.achievementID), ["first_day"])

        store.deleteAll()
        XCTAssertTrue(store.allDays().isEmpty)
        XCTAssertEqual(store.loadUnlockedAchievements().map(\.achievementID), ["first_day"],
                       "deleting history revoked a badge")
    }

    // MARK: - Writing back

    /// Reading an old day, saving it, and reading it again must not lose anything. This is what
    /// happens the first time the user opens the app after an update.
    func testSavingAnOldDayBackDoesNotLoseIt() {
        let store = store()
        guard var day = store.loadDay("2025-11-04") else { return XCTFail("the oldest day did not load") }
        let keysBefore = day.totalKeyPresses
        day.totalKeyPresses += 1
        store.saveDay(day)

        guard let reloaded = store.loadDay("2025-11-04") else { return XCTFail("the day vanished on save") }
        XCTAssertEqual(reloaded.totalKeyPresses, keysBefore + 1)
        XCTAssertEqual(reloaded.leftClicks, 733)
        XCTAssertEqual(reloaded.cursorDistancePixels, 412_300.5, accuracy: 0.001)
    }

    /// Retention deletes by date and must not reach past the boundary.
    func testDeletingBeforeADateLeavesThatDateAlone() {
        let store = store()
        store.deleteDays(before: "2025-12-19")
        XCTAssertEqual(store.allDays().map(\.day), ["2025-12-19"])
    }

    // MARK: - Export

    /// The CSV is the format most likely to leave the machine, and it must carry no application
    /// names — a list of what you run is a description of you.
    func testTheCSVExportOfAnOldDatabaseNamesNoApplications() {
        guard let data = store().exportAllAsCSV(dayStartHour: 5),
              let csv = String(data: data, encoding: .utf8) else {
            return XCTFail("the export produced nothing")
        }
        XCTAssertTrue(csv.hasPrefix("date,active_seconds"))
        XCTAssertEqual(csv.split(separator: "\n").count, 3, "a header and two days")
        XCTAssertFalse(csv.contains("Xcode"))
        XCTAssertFalse(csv.contains("Chrome"))
        XCTAssertFalse(csv.contains("com.apple"))
    }
}
