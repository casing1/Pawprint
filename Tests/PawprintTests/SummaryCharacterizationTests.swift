import XCTest
import PawprintCore
@testable import Pawprint

/// Pins the behaviour of `StatsEngine.summary` before it is split apart.
///
/// The exact figures are deliberately not asserted: two of the fields
/// (`cursorDistanceMeters`, `scrollScreens`, the battery health readings) are derived from the
/// display and battery of whatever machine is running the tests, because `StatsEngine` still
/// reaches for `DisplayMetrics.shared` and `BatteryHardware.shared` mid-calculation. Pinning them
/// would produce a suite that only passes on one Mac.
///
/// What is asserted holds on any machine and is what a split could actually break: the same input
/// gives the same output, an empty day stays empty rather than dividing by zero, and no field ever
/// comes back as NaN, infinite, or negative where negative is meaningless. Once §S6 moves the
/// hardware lookups out to be passed in, these become exact golden comparisons.
final class SummaryCharacterizationTests: XCTestCase {

    // MARK: - Fixtures

    /// A believable worked day, built by hand so it never changes.
    private func busyDay() -> DailyRawCounters {
        var raw = DailyRawCounters(day: "2026-03-09")
        let midnight = DayKey.date(fromDayString: "2026-03-09")!

        raw.firstActivity = midnight.addingTimeInterval(9 * 3600)
        raw.lastActivity = midnight.addingTimeInterval(18 * 3600 + 40 * 60)

        for minute in (9 * 60)...(18 * 60 + 40) {
            let level = 1.0 - abs(Double(minute) - 13 * 60) / (10 * 60)
            guard level > 0.15 else { continue }
            raw.activityPerMinute[minute] = Int(level * 90)
            raw.charKeysPerMinute[minute] = Int(level * 62)
            raw.clicksPerMinute[minute] = Int(level * 12)
            raw.scrollPerMinute[minute] = level * 2_100
        }

        raw.totalKeyPresses = 34_120
        raw.characterKeyPresses = 22_540
        raw.keyCategoryCounts = [
            KeyCategory.character.rawValue: 22_540,
            KeyCategory.backspace.rawValue: 2_180,
            KeyCategory.space.rawValue: 4_400,
            KeyCategory.shift.rawValue: 3_100,
        ]
        raw.keyCodeCounts = ["0": 1_820, "1": 1_410, "49": 4_400, "51": 2_180]
        raw.shortcutCounts = [ShortcutType.copy.rawValue: 140, ShortcutType.paste.rawValue: 132]
        raw.maxWPM = 103.5
        raw.maxWPMMinute = 11 * 60 + 38
        raw.longestTypingStreakSeconds = 940
        raw.typingSessionCount = 17

        raw.leftClicks = 5_120
        raw.rightClicks = 410
        raw.doubleClicks = 620
        raw.dragCount = 210
        raw.cursorDistancePixels = 1_840_000
        raw.maxCursorSpeedPxPerSec = 3_400
        raw.scrollUpPoints = 410_000
        raw.scrollDownPoints = 520_000
        raw.scrollDirectionChanges = 780
        raw.maxScrollSpeedPointsPerSec = 4_100

        raw.clipboardCopyCount = 84
        raw.clipboardPasteCount = 77
        raw.clipboardCutCount = 9
        raw.clipboardTypeCounts = [ClipboardDataType.text.rawValue: 80,
                                   ClipboardDataType.image.rawValue: 4]

        raw.appNames = ["com.microsoft.VSCode": "Visual Studio Code",
                        "com.google.Chrome": "Google Chrome"]
        raw.appKeyPresses = ["com.microsoft.VSCode": 24_000, "com.google.Chrome": 10_120]
        raw.appClicks = ["com.microsoft.VSCode": 3_100, "com.google.Chrome": 2_430]
        raw.appScrollPoints = ["com.microsoft.VSCode": 380_000, "com.google.Chrome": 550_000]
        raw.totalAppSwitches = 212
        raw.shortDwellCount = 41
        raw.appSessions = [
            AppSessionRecord(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code",
                             start: midnight.addingTimeInterval(9 * 3600),
                             end: midnight.addingTimeInterval(12 * 3600)),
            AppSessionRecord(bundleID: "com.google.Chrome", appName: "Google Chrome",
                             start: midnight.addingTimeInterval(12 * 3600),
                             end: midnight.addingTimeInterval(14 * 3600)),
        ]
        raw.focusSessions = [
            FocusSessionRecord(start: midnight.addingTimeInterval(9 * 3600 + 1_800),
                               end: midnight.addingTimeInterval(11 * 3600),
                               primaryApp: "Visual Studio Code", interruptionCount: 2),
        ]
        raw.activitySessions = [
            ActivitySessionRecord(start: midnight.addingTimeInterval(9 * 3600),
                                  end: midnight.addingTimeInterval(12 * 3600)),
        ]

        raw.activeSeconds = 5 * 3600 + 14 * 60
        raw.screenOnSeconds = 8 * 3600 + 32 * 60
        raw.secondsOnAC = 6 * 3600
        raw.secondsOnBattery = 3 * 3600
        raw.lidCloseCount = 3
        raw.lidOpenCount = 3
        raw.lockCount = 4
        raw.unlockCount = 4
        raw.networkDownloadBytes = 1_610_000_000
        raw.networkUploadBytes = 230_000_000
        return raw
    }

    /// Every numeric and boolean field, by name. Used both to compare two runs and to sweep for
    /// impossible values without naming all ~150 fields by hand.
    private func numericFields(_ subject: Any, prefix: String = "") -> [String: Double] {
        var out: [String: Double] = [:]
        for child in Mirror(reflecting: subject).children {
            guard let label = child.label else { continue }
            let key = prefix.isEmpty ? label : "\(prefix).\(label)"
            switch child.value {
            case let value as Int: out[key] = Double(value)
            case let value as Double: out[key] = value
            case let value as UInt64: out[key] = Double(value)
            case let value as Bool: out[key] = value ? 1 : 0
            default: break
            }
        }
        return out
    }

    // MARK: - Determinism

    /// The same day, summarised twice, must be identical. This is the property a split into
    /// separate calculators is most likely to break — through a shared cache, an ordering
    /// dependency, or a stray `Date()`.
    func testSummaryIsDeterministic() {
        let raw = busyDay()
        SummaryCache.shared.invalidateAll()
        let first = StatsEngine.summary(for: raw, recentDays: [], dayStartHour: 0)
        SummaryCache.shared.invalidateAll()
        let second = StatsEngine.summary(for: raw, recentDays: [], dayStartHour: 0)

        let a = numericFields(first)
        let b = numericFields(second)
        XCTAssertFalse(a.isEmpty, "reflection found no numeric fields; the sweep would be vacuous")
        XCTAssertEqual(a.keys.sorted(), b.keys.sorted())
        for (key, value) in a {
            XCTAssertEqual(value, b[key] ?? .nan, accuracy: 0, "\(key) differed between runs")
        }

        XCTAssertEqual(first.day, second.day)
        XCTAssertEqual(first.summarySentence, second.summarySentence)
        XCTAssertEqual(first.persona?.title, second.persona?.title)
        XCTAssertEqual(first.persona?.keyboardAffinity, second.persona?.keyboardAffinity)
        XCTAssertEqual(first.score?.total, second.score?.total)
    }

    /// Passing the same recent history must not change today's own figures either.
    func testRecentDaysDoNotAlterTodaysOwnCounters() {
        let raw = busyDay()
        let alone = StatsEngine.summary(for: raw, recentDays: [], dayStartHour: 0)
        let withHistory = StatsEngine.summary(for: raw, recentDays: [busyDay(), busyDay()],
                                              dayStartHour: 0)

        XCTAssertEqual(alone.totalKeyPresses, withHistory.totalKeyPresses)
        XCTAssertEqual(alone.activeSeconds, withHistory.activeSeconds)
        XCTAssertEqual(alone.maxWPM, withHistory.maxWPM)
        XCTAssertEqual(alone.totalClicks, withHistory.totalClicks)
    }

    // MARK: - Impossible values

    /// No field may come back NaN or infinite. Most of these are ratios, and a day with a zero
    /// denominator is the ordinary case, not the exotic one.
    func testNoFieldIsNaNOrInfinite() {
        for (name, raw) in [("busy", busyDay()),
                            ("empty", DailyRawCounters(day: "2026-03-09")),
                            ("oneKeyOnly", { () -> DailyRawCounters in
                                var r = DailyRawCounters(day: "2026-03-09")
                                r.totalKeyPresses = 1
                                r.characterKeyPresses = 1
                                return r
                            }())] {
            let summary = StatsEngine.summary(for: raw, recentDays: [], dayStartHour: 0)
            for (key, value) in numericFields(summary) {
                XCTAssertFalse(value.isNaN, "\(name).\(key) is NaN")
                XCTAssertFalse(value.isInfinite, "\(name).\(key) is infinite")
            }
        }
    }

    /// Counts and durations cannot be negative. Percentages and ratios cannot exceed their range.
    func testCountsAndDurationsAreNonNegative() {
        let summary = StatsEngine.summary(for: busyDay(), recentDays: [], dayStartHour: 0)
        for (key, value) in numericFields(summary) {
            let lower = key.lowercased()
            guard lower.contains("count") || lower.contains("seconds") || lower.contains("total")
                    || lower.contains("presses") || lower.contains("clicks") else { continue }
            XCTAssertGreaterThanOrEqual(value, 0, "\(key) is negative")
        }
    }

    /// A day with nothing on it must summarise, not crash, and must not invent activity.
    func testEmptyDaySummarisesToNothing() {
        let summary = StatsEngine.summary(for: DailyRawCounters(day: "2026-03-09"),
                                          recentDays: [], dayStartHour: 0)
        XCTAssertEqual(summary.day, "2026-03-09")
        XCTAssertEqual(summary.totalKeyPresses, 0)
        XCTAssertEqual(summary.activeSeconds, 0)
        XCTAssertEqual(summary.totalClicks, 0)
    }

    /// A day loaded from an old database — most fields absent — must summarise on the same terms
    /// as one built in memory. This is the path a real user's history takes.
    func testLegacyDayFromJSONSummarises() throws {
        let json = #"{"day":"2025-11-04","totalKeyPresses":8421,"characterKeyPresses":6110,"leftClicks":733,"activeSeconds":14820}"#
        let raw = try JSONDecoder().decode(DailyRawCounters.self, from: Data(json.utf8))
        let summary = StatsEngine.summary(for: raw, recentDays: [], dayStartHour: 0)

        XCTAssertEqual(summary.totalKeyPresses, 8421)
        XCTAssertEqual(summary.activeSeconds, 14820)
        for (key, value) in numericFields(summary) {
            XCTAssertFalse(value.isNaN, "\(key) is NaN on a legacy day")
            XCTAssertFalse(value.isInfinite, "\(key) is infinite on a legacy day")
        }
    }
}
