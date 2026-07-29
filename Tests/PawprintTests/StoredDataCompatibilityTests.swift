import XCTest
@testable import Pawprint

/// What happens when today's build reads yesterday's database.
///
/// A day is stored as one JSON blob, so the `Codable` property names *are* the schema. A rename
/// drops that field for every existing user, silently, and the loss only shows up as a statistic
/// quietly reading zero. These tests hold the shape in place before any of it is moved.
final class StoredDataCompatibilityTests: XCTestCase {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private func decode(_ json: String) throws -> DailyRawCounters {
        try decoder.decode(DailyRawCounters.self, from: Data(json.utf8))
    }

    /// The oldest shape still in the wild: a day key and a handful of counters, written before
    /// most fields existed. It must load, and everything absent must come back as a zero rather
    /// than as a decode failure that discards the whole day.
    func testAVeryOldDayLoadsWithZeroesForFieldsThatDidNotExist() throws {
        let raw = try decode("""
        {
          "day": "2025-11-04",
          "totalKeyPresses": 8421,
          "characterKeyPresses": 6110,
          "leftClicks": 733,
          "activeSeconds": 14_820
        }
        """.replacingOccurrences(of: "_", with: ""))

        XCTAssertEqual(raw.day, "2025-11-04")
        XCTAssertEqual(raw.totalKeyPresses, 8421)
        XCTAssertEqual(raw.characterKeyPresses, 6110)
        XCTAssertEqual(raw.leftClicks, 733)
        XCTAssertEqual(raw.activeSeconds, 14820)

        // Added later. Absent must mean zero, not "throw away the day".
        XCTAssertEqual(raw.scrollDirectionChanges, 0)
        XCTAssertEqual(raw.lidCloseCount, 0)
        XCTAssertEqual(raw.screenOnSeconds, 0)
        XCTAssertEqual(raw.networkDownloadBytes, 0)
        XCTAssertTrue(raw.focusSessions.isEmpty)
        XCTAssertTrue(raw.appSessions.isEmpty)
        XCTAssertTrue(raw.keyCodeCounts.isEmpty)
    }

    /// Only the day key is genuinely required — it is the primary key the row is filed under.
    func testADayKeyAloneIsEnough() throws {
        let raw = try decode(#"{"day":"2026-01-01"}"#)
        XCTAssertEqual(raw.day, "2026-01-01")
        XCTAssertEqual(raw.totalKeyPresses, 0)
    }

    /// Fields written by a *newer* build must not stop an older one reading the day. Someone who
    /// downgrades should lose the new statistic, not the day.
    func testUnknownFieldsAreIgnored() throws {
        let raw = try decode("""
        {"day":"2026-01-02","totalKeyPresses":10,"somethingFromTheFuture":{"nested":true}}
        """)
        XCTAssertEqual(raw.totalKeyPresses, 10)
    }

    /// A full round trip must not lose anything, which is what makes it safe to read a day,
    /// mutate one counter and write it back.
    func testRoundTripIsLossless() throws {
        var raw = DailyRawCounters(day: "2026-03-09")
        raw.totalKeyPresses = 1234
        raw.characterKeyPresses = 900
        raw.keyCodeCounts = ["0": 40, "49": 120]
        raw.keyCategoryCounts = [KeyCategory.character.rawValue: 900]
        raw.leftClicks = 88
        raw.cursorDistancePixels = 91_234.5
        raw.scrollUpPoints = 12_000
        raw.scrollDownPoints = 18_500
        raw.activeSeconds = 9_000
        raw.screenOnSeconds = 14_000
        raw.maxWPM = 103.5
        raw.appNames = ["com.apple.dt.Xcode": "Xcode"]
        raw.appKeyPresses = ["com.apple.dt.Xcode": 700]
        raw.networkDownloadBytes = 5_000_000
        raw.firstActivity = Date(timeIntervalSince1970: 1_772_000_000)
        raw.lastActivity = Date(timeIntervalSince1970: 1_772_040_000)

        let restored = try decoder.decode(DailyRawCounters.self, from: encoder.encode(raw))

        XCTAssertEqual(restored.totalKeyPresses, raw.totalKeyPresses)
        XCTAssertEqual(restored.characterKeyPresses, raw.characterKeyPresses)
        XCTAssertEqual(restored.keyCodeCounts, raw.keyCodeCounts)
        XCTAssertEqual(restored.keyCategoryCounts, raw.keyCategoryCounts)
        XCTAssertEqual(restored.leftClicks, raw.leftClicks)
        XCTAssertEqual(restored.cursorDistancePixels, raw.cursorDistancePixels)
        XCTAssertEqual(restored.scrollUpPoints, raw.scrollUpPoints)
        XCTAssertEqual(restored.scrollDownPoints, raw.scrollDownPoints)
        XCTAssertEqual(restored.activeSeconds, raw.activeSeconds)
        XCTAssertEqual(restored.screenOnSeconds, raw.screenOnSeconds)
        XCTAssertEqual(restored.maxWPM, raw.maxWPM)
        XCTAssertEqual(restored.appNames, raw.appNames)
        XCTAssertEqual(restored.appKeyPresses, raw.appKeyPresses)
        XCTAssertEqual(restored.networkDownloadBytes, raw.networkDownloadBytes)
        XCTAssertEqual(restored.firstActivity?.timeIntervalSince1970,
                       raw.firstActivity?.timeIntervalSince1970)
    }

    /// Corrupt JSON must fail as a decode error the caller can see. Today the store swallows this
    /// with `try?`; S7 changes that, and this test says what the model layer does either way.
    func testCorruptJSONThrowsRatherThanReturningAnEmptyDay() {
        XCTAssertThrowsError(try decode("{ this is not json"))
        XCTAssertThrowsError(try decode(#"{"day":123}"#))
    }

    // MARK: - Settings

    /// Settings share the same hazard: a missing key must fall back to the documented default, not
    /// reset the user's whole configuration.
    func testSettingsFillInDefaultsForMissingKeys() throws {
        let settings = try decoder.decode(AppSettings.self, from: Data(#"{}"#.utf8))
        let fresh = AppSettings()

        XCTAssertEqual(settings.dayStartHour, fresh.dayStartHour)
        XCTAssertEqual(settings.retentionDays, fresh.retentionDays)
        XCTAssertEqual(settings.focusThresholdSeconds, fresh.focusThresholdSeconds)
        XCTAssertEqual(settings.isPaused, fresh.isPaused)
        XCTAssertEqual(settings.excludedApps.map(\.bundleID), fresh.excludedApps.map(\.bundleID))
    }

    /// A stored value must win over the default — the failure mode being guarded is a decoder that
    /// quietly hands back a fresh `AppSettings` and wipes what the user chose.
    func testStoredSettingsSurviveDecoding() throws {
        var settings = AppSettings()
        settings.dayStartHour = 4
        settings.retentionDays = 400
        settings.isPaused = true
        settings.excludedApps = [ExcludedApp(bundleID: "com.apple.Passwords",
                                            displayName: "Passwords")]

        let restored = try decoder.decode(AppSettings.self, from: encoder.encode(settings))

        XCTAssertEqual(restored.dayStartHour, 4)
        XCTAssertEqual(restored.retentionDays, 400)
        XCTAssertTrue(restored.isPaused)
        XCTAssertEqual(restored.excludedApps.map(\.bundleID), ["com.apple.Passwords"])
    }
}
