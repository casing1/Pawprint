import XCTest
import PawprintCore
@testable import Pawprint

/// Section D: what the Mac's own state does to a day.
///
/// Sleep, wake, lock, unlock, display sleep, the lid, the charger, the battery, thermal pressure,
/// external displays and the audio device. None of it is the user typing, all of it is recorded,
/// and until now none of it could be checked without closing a real laptop lid and hoping.
///
/// These drive `ActivityCenter` itself rather than a value type, because that is where the
/// interesting behaviour is: the category gate, the pause gate, and the fact that some of these
/// counters are events while others are elapsed seconds. `PowerAndSleepMonitor` above it is
/// IOKit plumbing — it decides *when* to call these, and that part is not testable off a machine.
final class SystemStateTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_772_000_000)

    private func center(_ settings: AppSettings = AppSettings()) -> ActivityCenter {
        ActivityCenter(store: InMemoryActivityStore(settings: settings), clock: SystemClock())
    }

    private func paused() -> AppSettings {
        var settings = AppSettings()
        settings.isPaused = true
        return settings
    }

    // MARK: - Sleep and wake

    func testSleepAndWakeAreRecordedAsAPair() {
        let center = center()
        center.recordMacState(SleepWakeRecord(type: .sleep, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .wake, timestamp: noon.addingTimeInterval(3600),
                                              durationSeconds: 3600))

        XCTAssertEqual(center.today.sleepWakeEvents.count, 2)
        XCTAssertEqual(center.today.sleepWakeEvents.first?.type, .sleep)
        XCTAssertEqual(center.today.sleepWakeEvents.last?.durationSeconds, 3600)
        // Sleep and wake are a timeline, not a tally — neither has a counter of its own.
        XCTAssertEqual(center.today.lockCount, 0)
        XCTAssertEqual(center.today.unlockCount, 0)
    }

    func testLockAndUnlockEachHaveTheirOwnCount() {
        let center = center()
        center.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .screenUnlock, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: noon))

        XCTAssertEqual(center.today.lockCount, 2)
        XCTAssertEqual(center.today.unlockCount, 1)
        XCTAssertEqual(center.today.sleepWakeEvents.count, 3)
    }

    func testChargerEventsCountSeparatelyFromLocks() {
        let center = center()
        center.recordMacState(SleepWakeRecord(type: .chargerConnect, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .chargerDisconnect, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .chargerConnect, timestamp: noon))

        XCTAssertEqual(center.today.chargerConnectCount, 2)
        XCTAssertEqual(center.today.chargerDisconnectCount, 1)
    }

    // MARK: - The category gates

    /// Sleep, wake, lock and unlock belong to the sleep/wake category; the charger belongs to
    /// power and peripherals. Turning one off must not silence the other.
    func testTheTwoCategoriesGateSeparately() {
        var noSleepWake = AppSettings()
        noSleepWake.collectSleepWake = false
        let a = center(noSleepWake)
        a.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: noon))
        a.recordMacState(SleepWakeRecord(type: .chargerConnect, timestamp: noon))
        XCTAssertEqual(a.today.lockCount, 0, "sleep/wake was off")
        XCTAssertEqual(a.today.chargerConnectCount, 1, "power was still on")

        var noPower = AppSettings()
        noPower.collectPowerPeripherals = false
        let b = center(noPower)
        b.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: noon))
        b.recordMacState(SleepWakeRecord(type: .chargerConnect, timestamp: noon))
        XCTAssertEqual(b.today.lockCount, 1, "sleep/wake was still on")
        XCTAssertEqual(b.today.chargerConnectCount, 0, "power was off")
    }

    /// Pause is the promise on the tin: nothing at all is recorded, whatever the categories say.
    func testPauseSilencesEverySystemSignal() {
        let center = center(paused())
        center.recordMacState(SleepWakeRecord(type: .screenLock, timestamp: noon))
        center.recordMacState(SleepWakeRecord(type: .chargerConnect, timestamp: noon))
        center.recordBatterySample(BatterySample(timestamp: noon, level: 80, isCharging: false))
        center.accumulatePowerTime(seconds: 60, onAC: false, lowPowerMode: true,
                                   elevatedThermal: true, at: noon)
        center.beginChargeSession(startLevel: 40, at: noon)
        center.recordLidChange(closed: true, at: noon)
        center.recordDisplayChange(connected: 1, disconnected: 0, totalDisplays: 2, at: noon)
        center.recordAudioOutputChange(at: noon)
        center.recordDisplaySleep(at: noon)
        center.recordDisplayWake(at: noon)
        center.accumulateScreenOnTime(seconds: 300, at: noon)
        center.recordNetworkTraffic(downloadBytes: 1_000, uploadBytes: 500, overSeconds: 10, at: noon)

        let today = center.today
        XCTAssertEqual(today.sleepWakeEvents.count, 0)
        XCTAssertEqual(today.batterySamples.count, 0)
        XCTAssertEqual(today.secondsOnBattery, 0)
        XCTAssertEqual(today.lowPowerModeSeconds, 0)
        XCTAssertEqual(today.elevatedThermalSeconds, 0)
        XCTAssertEqual(today.chargeSessions.count, 0)
        XCTAssertEqual(today.lidCloseCount, 0)
        XCTAssertEqual(today.externalDisplayConnectCount, 0)
        XCTAssertEqual(today.audioOutputDeviceChangeCount, 0)
        XCTAssertEqual(today.displaySleepCount, 0)
        XCTAssertEqual(today.displayWakeCount, 0)
        XCTAssertEqual(today.screenOnSeconds, 0)
        XCTAssertEqual(today.networkDownloadBytes, 0)
    }

    // MARK: - Power and thermal time

    /// Elapsed seconds, not events: the sampler reports an interval and the totals must add up.
    func testPowerTimeAccumulatesIntoTheStateItWasSpentIn() {
        let center = center()
        center.accumulatePowerTime(seconds: 60, onAC: true, lowPowerMode: false,
                                   elevatedThermal: false, at: noon)
        center.accumulatePowerTime(seconds: 30, onAC: false, lowPowerMode: true,
                                   elevatedThermal: false, at: noon)
        center.accumulatePowerTime(seconds: 15, onAC: false, lowPowerMode: false,
                                   elevatedThermal: true, at: noon)

        XCTAssertEqual(center.today.secondsOnAC, 60)
        XCTAssertEqual(center.today.secondsOnBattery, 45)
        XCTAssertEqual(center.today.lowPowerModeSeconds, 30)
        XCTAssertEqual(center.today.elevatedThermalSeconds, 15)
    }

    /// Low power and thermal pressure are orthogonal to the power source and to each other.
    func testLowPowerAndThermalCanBothBeTrueAtOnce() {
        let center = center()
        center.accumulatePowerTime(seconds: 20, onAC: true, lowPowerMode: true,
                                   elevatedThermal: true, at: noon)
        XCTAssertEqual(center.today.secondsOnAC, 20)
        XCTAssertEqual(center.today.secondsOnBattery, 0)
        XCTAssertEqual(center.today.lowPowerModeSeconds, 20)
        XCTAssertEqual(center.today.elevatedThermalSeconds, 20)
    }

    func testAZeroOrNegativeIntervalIsIgnored() {
        let center = center()
        center.accumulatePowerTime(seconds: 0, onAC: true, lowPowerMode: false,
                                   elevatedThermal: false, at: noon)
        center.accumulatePowerTime(seconds: -100, onAC: true, lowPowerMode: false,
                                   elevatedThermal: false, at: noon)
        center.accumulateScreenOnTime(seconds: 0, at: noon)
        center.accumulateScreenOnTime(seconds: -60, at: noon)

        XCTAssertEqual(center.today.secondsOnAC, 0)
        XCTAssertEqual(center.today.screenOnSeconds, 0)
    }

    func testScreenOnTimeAddsUp() {
        let center = center()
        center.accumulateScreenOnTime(seconds: 300, at: noon)
        center.accumulateScreenOnTime(seconds: 45, at: noon)
        XCTAssertEqual(center.today.screenOnSeconds, 345)
    }

    /// Screen-on time is the one system figure not gated on a category — it is how long you were
    /// at the machine, which the whole Today tab is built on.
    func testScreenOnTimeIsNotGatedOnACategory() {
        var settings = AppSettings()
        settings.collectSleepWake = false
        settings.collectPowerPeripherals = false
        let center = center(settings)
        center.accumulateScreenOnTime(seconds: 120, at: noon)
        XCTAssertEqual(center.today.screenOnSeconds, 120)
    }

    // MARK: - Battery

    func testBatterySamplesAreKeptInOrder() {
        let center = center()
        for (offset, level) in [(0, 100), (60, 98), (120, 95)] {
            center.recordBatterySample(BatterySample(timestamp: noon.addingTimeInterval(Double(offset)),
                                                     level: level, isCharging: false))
        }
        XCTAssertEqual(center.today.batterySamples.map(\.level), [100, 98, 95])
    }

    /// A day's battery timeline is bounded. A machine that charges and discharges all day would
    /// otherwise grow one JSON blob without limit, and the oldest samples are the ones to lose.
    func testTheBatteryTimelineIsCappedAndKeepsTheNewest() {
        let center = center()
        for i in 0..<520 {
            center.recordBatterySample(BatterySample(timestamp: noon.addingTimeInterval(Double(i)),
                                                     level: i % 101, isCharging: false))
        }
        XCTAssertEqual(center.today.batterySamples.count, 500)
        XCTAssertEqual(center.today.batterySamples.first?.level, 20 % 101, "the oldest 20 should have gone")
        XCTAssertEqual(center.today.batterySamples.last?.level, 519 % 101)
    }

    // MARK: - Charge sessions

    func testAChargeSessionOpensAndCloses() {
        let center = center()
        center.beginChargeSession(startLevel: 42, at: noon)
        center.endChargeSession(endLevel: 100, at: noon.addingTimeInterval(5400))

        XCTAssertEqual(center.today.chargeSessions.count, 1)
        let session = center.today.chargeSessions[0]
        XCTAssertEqual(session.startLevel, 42)
        XCTAssertEqual(session.endLevel, 100)
        XCTAssertEqual(session.end, noon.addingTimeInterval(5400))
    }

    /// Unplugging without ever having plugged in must not invent a session.
    func testEndingASessionThatNeverStartedDoesNothing() {
        let center = center()
        center.endChargeSession(endLevel: 80, at: noon)
        XCTAssertTrue(center.today.chargeSessions.isEmpty)
    }

    /// The end closes the most recent *open* session, so a completed one is never reopened.
    func testEndingClosesTheOpenSessionAndLeavesFinishedOnesAlone() {
        let center = center()
        center.beginChargeSession(startLevel: 10, at: noon)
        center.endChargeSession(endLevel: 60, at: noon.addingTimeInterval(600))
        center.beginChargeSession(startLevel: 55, at: noon.addingTimeInterval(1200))
        center.endChargeSession(endLevel: 90, at: noon.addingTimeInterval(1800))

        XCTAssertEqual(center.today.chargeSessions.count, 2)
        XCTAssertEqual(center.today.chargeSessions[0].endLevel, 60)
        XCTAssertEqual(center.today.chargeSessions[1].endLevel, 90)
    }

    // MARK: - Lid

    func testClosingAndOpeningTheLidCountSeparately() {
        let center = center()
        center.recordLidChange(closed: true, at: noon)
        center.recordLidChange(closed: false, closedForSeconds: 900, at: noon.addingTimeInterval(900))

        XCTAssertEqual(center.today.lidCloseCount, 1)
        XCTAssertEqual(center.today.lidOpenCount, 1)
        XCTAssertEqual(center.today.lidClosedSeconds, 900)
    }

    /// Only the open half carries a duration, and a nonsensical one is floored at zero rather
    /// than subtracted from the day.
    func testANegativeClosedDurationCannotReduceTheTotal() {
        let center = center()
        center.recordLidChange(closed: false, closedForSeconds: 600, at: noon)
        center.recordLidChange(closed: false, closedForSeconds: -10_000, at: noon)
        XCTAssertEqual(center.today.lidClosedSeconds, 600)
    }

    func testClosingTheLidCarriesNoDuration() {
        let center = center()
        center.recordLidChange(closed: true, closedForSeconds: 999, at: noon)
        XCTAssertEqual(center.today.lidClosedSeconds, 0, "a close is the start of the interval")
    }

    // MARK: - Displays and audio

    func testDisplayConnectionsCountAndThePeakIsRemembered() {
        let center = center()
        center.recordDisplayChange(connected: 2, disconnected: 0, totalDisplays: 3, at: noon)
        center.recordDisplayChange(connected: 0, disconnected: 2, totalDisplays: 1, at: noon)

        XCTAssertEqual(center.today.externalDisplayConnectCount, 2)
        XCTAssertEqual(center.today.externalDisplayDisconnectCount, 2)
        XCTAssertEqual(center.today.maxSimultaneousDisplays, 3, "the peak went down with the count")
    }

    func testDisplaySleepAndWakeAreCountedSeparately() {
        let center = center()
        center.recordDisplaySleep(at: noon)
        center.recordDisplayWake(at: noon)
        center.recordDisplaySleep(at: noon)

        XCTAssertEqual(center.today.displaySleepCount, 2)
        XCTAssertEqual(center.today.displayWakeCount, 1)
    }

    func testAudioOutputChangesAreCounted() {
        let center = center()
        center.recordAudioOutputChange(at: noon)
        center.recordAudioOutputChange(at: noon)
        XCTAssertEqual(center.today.audioOutputDeviceChangeCount, 2)
    }

    // MARK: - Network

    func testNetworkTrafficAccumulatesAndKeepsItsPeakRate() {
        let center = center()
        center.recordNetworkTraffic(downloadBytes: 10_000, uploadBytes: 2_000, overSeconds: 10, at: noon)
        center.recordNetworkTraffic(downloadBytes: 1_000, uploadBytes: 500, overSeconds: 10, at: noon)

        XCTAssertEqual(center.today.networkDownloadBytes, 11_000)
        XCTAssertEqual(center.today.networkUploadBytes, 2_500)
        XCTAssertEqual(center.today.peakDownloadBytesPerSec, 1_000, accuracy: 0.001)
        XCTAssertEqual(center.today.peakUploadBytesPerSec, 200, accuracy: 0.001)
    }

    /// A zero-length window would divide by zero; the bytes still count, the rate does not.
    func testAZeroLengthWindowStillCountsTheBytes() {
        let center = center()
        center.recordNetworkTraffic(downloadBytes: 5_000, uploadBytes: 0, overSeconds: 0, at: noon)
        XCTAssertEqual(center.today.networkDownloadBytes, 5_000)
        XCTAssertEqual(center.today.peakDownloadBytesPerSec, 0)
    }

    // MARK: - Privacy

    /// Nothing here may retain an identity, an address or a name. The system signals are counts,
    /// durations and levels — a battery percentage and a display count say nothing about who you
    /// are or what you were doing.
    func testTheSystemSignalsCarryNoIdentifyingDetail() {
        let center = center()
        center.recordDisplayChange(connected: 1, disconnected: 0, totalDisplays: 2, at: noon)
        center.recordAudioOutputChange(at: noon)
        center.recordNetworkTraffic(downloadBytes: 1_000, uploadBytes: 1_000, overSeconds: 1, at: noon)
        center.recordBatterySample(BatterySample(timestamp: noon, level: 55, isCharging: true))

        let encoded = try! JSONEncoder().encode(center.today)
        let text = String(data: encoded, encoding: .utf8)!
        // The display and audio counters are counts; there is no field anywhere for a device name
        // or a host, and this is what would catch one being added.
        for forbidden in ["deviceName", "displayName", "host", "url", "ssid", "interface", "serial"] {
            XCTAssertFalse(text.contains(forbidden), "the day now stores \(forbidden)")
        }
    }
}
