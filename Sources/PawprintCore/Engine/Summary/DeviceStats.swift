import Foundation

/// The Mac's own state for the day: sleep and wake, the screen, the battery, the lid, attached
/// displays, audio and network volume.
///
/// The battery's cycle count and health are the machine's, not the day's — they are the same
/// number whichever day is being summarised — so they arrive as `MachineFacts` rather than being
/// looked up from IOKit part-way through the arithmetic.
package enum DeviceStats {

    package static func apply(_ raw: DailyRawCounters,
                              to s: inout DailySummary,
                              machine: MachineFacts) {
        applySleepAndWake(raw, to: &s)
        applyPower(raw, to: &s, machine: machine)
        applyLidAndDisplays(raw, to: &s)
        applyScreenTime(raw, to: &s)
        applyNetwork(raw, to: &s)
    }

    private static func applySleepAndWake(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.sleepCount = raw.sleepWakeEvents.filter { $0.type == .sleep }.count
        s.wakeCount = raw.sleepWakeEvents.filter { $0.type == .wake }.count
        let sleepDurations = raw.sleepWakeEvents.filter { $0.type == .wake }.map(\.durationSeconds)
        s.totalSleepSeconds = sleepDurations.reduce(0, +)
        s.longestSleepSeconds = sleepDurations.max() ?? 0
        s.lockCount = raw.lockCount
        s.unlockCount = raw.unlockCount
    }

    private static func applyPower(_ raw: DailyRawCounters,
                                   to s: inout DailySummary,
                                   machine: MachineFacts) {
        s.chargerConnectCount = raw.chargerConnectCount
        s.chargerDisconnectCount = raw.chargerDisconnectCount
        let levels = raw.batterySamples.map(\.level)
        s.minBatteryLevel = levels.min()
        s.maxBatteryLevel = levels.max()
        s.currentBatteryLevel = raw.batterySamples.last?.level
        s.secondsOnBattery = raw.secondsOnBattery
        s.secondsOnAC = raw.secondsOnAC
        s.chargeSessionCount = raw.chargeSessions.count
        s.totalChargedPercent = raw.chargeSessions.compactMap(\.gainedPercent).reduce(0, +)
        s.batteryDrainedPercent = drained(raw.batterySamples)
        s.lowPowerModeSeconds = raw.lowPowerModeSeconds
        s.elevatedThermalSeconds = raw.elevatedThermalSeconds
        s.batteryTimeline = raw.batterySamples
        s.batteryCycleCount = machine.batteryCycleCount
        s.batteryHealthPercent = machine.batteryHealthPercent
    }

    private static func applyLidAndDisplays(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.lidCloseCount = raw.lidCloseCount
        s.lidOpenCount = raw.lidOpenCount
        s.lidClosedSeconds = raw.lidClosedSeconds

        s.externalDisplayConnectCount = raw.externalDisplayConnectCount
        s.externalDisplayDisconnectCount = raw.externalDisplayDisconnectCount
        s.maxSimultaneousDisplays = raw.maxSimultaneousDisplays
        s.audioOutputDeviceChangeCount = raw.audioOutputDeviceChangeCount
        s.displaySleepCount = raw.displaySleepCount
        s.displayWakeCount = raw.displayWakeCount
    }

    private static func applyScreenTime(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.screenOnSeconds = raw.screenOnSeconds
        s.screenIdleSeconds = max(0, raw.screenOnSeconds - raw.activeSeconds)
        if raw.screenOnSeconds > 0 {
            s.screenUtilizationPercent = min(100, Int((Double(raw.activeSeconds) / Double(raw.screenOnSeconds) * 100).rounded()))
        }
    }

    private static func applyNetwork(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.networkDownloadBytes = raw.networkDownloadBytes
        s.networkUploadBytes = raw.networkUploadBytes
        s.networkTotalBytes = raw.networkDownloadBytes + raw.networkUploadBytes
        s.peakDownloadBytesPerSec = raw.peakDownloadBytesPerSec
        s.peakUploadBytesPerSec = raw.peakUploadBytesPerSec
    }

    /// Total battery percentage consumed today, summing only the downward steps between
    /// consecutive samples so recharges don't cancel out the drain that preceded them.
    private static func drained(_ samples: [BatterySample]) -> Int {
        guard samples.count > 1 else { return 0 }
        var drained = 0
        for (previous, current) in zip(samples, samples.dropFirst()) {
            if current.level < previous.level {
                drained += previous.level - current.level
            }
        }
        return drained
    }
}
