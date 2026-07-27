import Foundation
import IOKit

/// Reads the battery's real physical characteristics from IOKit so battery-percentage figures
/// can be turned into actual energy (watt-hours) instead of a made-up constant.
///
/// `NominalChargeCapacity` (mAh) is the pack's present full-charge capacity and `Voltage` (mV)
/// its current terminal voltage; their product is the energy a full charge holds. Values are
/// read once at launch — they drift only over months of battery wear.
final class BatteryHardware {
    static let shared = BatteryHardware()

    /// Energy stored in a full charge, in watt-hours. Nil on desktop Macs (no battery).
    private(set) var fullChargeWattHours: Double?
    /// Battery charge cycles the pack has been through.
    private(set) var cycleCount: Int?
    /// Battery health as a percentage of its original design capacity.
    private(set) var healthPercent: Int?

    /// Watt-hours corresponding to one percent of battery. Nil when there's no battery.
    var wattHoursPerPercent: Double? {
        fullChargeWattHours.map { $0 / 100.0 }
    }

    private init() {
        read()
    }

    func read() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var unmanagedProps: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanagedProps, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanagedProps?.takeRetainedValue() as? [String: Any] else { return }

        let milliVolts = (props["Voltage"] as? Int).map(Double.init)
        let capacityMAh = (props["NominalChargeCapacity"] as? Int)
            ?? (props["AppleRawMaxCapacity"] as? Int)
            ?? (props["DesignCapacity"] as? Int)

        if let capacityMAh, let milliVolts, capacityMAh > 0, milliVolts > 0 {
            // (mAh × mV) / 1_000_000 = Wh
            fullChargeWattHours = Double(capacityMAh) * milliVolts / 1_000_000
        }

        cycleCount = props["CycleCount"] as? Int

        if let design = props["DesignCapacity"] as? Int, design > 0, let capacityMAh {
            // A new pack often measures slightly above its design capacity; showing "101%" reads
            // like a bug, so cap the displayed health at 100.
            healthPercent = min(100, Int((Double(capacityMAh) / Double(design) * 100).rounded()))
        }
    }

    /// Converts a battery-percentage delta into watt-hours.
    func wattHours(fromPercent percent: Int) -> Double? {
        guard let perPercent = wattHoursPerPercent, percent > 0 else { return nil }
        return Double(percent) * perPercent
    }
}
