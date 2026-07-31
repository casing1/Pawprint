import Foundation

/// What the statistics need to know about the machine they are describing.
///
/// Two figures depend on the panel in front of you — "your cursor travelled 123 m" and "you
/// scrolled 863 screen-heights" — and three on the battery pack. Neither is derivable from a day's
/// counters, and both used to be fetched mid-calculation through `DisplayCalibration.current` and
/// `BatteryHardware.shared`.
///
/// That is what stopped `StatsEngine.summary` being a function of its arguments: the same day could
/// produce different numbers depending on which display happened to be attached when it was called,
/// and there was nowhere to stand to say what it *should* produce. Passing them in makes the
/// dependency visible at the call site and lets a test state the machine it is describing.
///
/// `.current` is the running application's, and remains the default so no caller had to change.
package struct MachineFacts {

    package var display: any DisplayCalibrating

    /// Battery charge cycles, `nil` on a desktop Mac.
    package var batteryCycleCount: Int?
    /// Battery health against its original design capacity, `nil` on a desktop Mac.
    package var batteryHealthPercent: Int?
    /// Watt-hours in one percent of the pack, `nil` on a desktop Mac. Turns a percentage drop
    /// into the energy conversions.
    package var wattHoursPerPercent: Double?

    package init(display: any DisplayCalibrating = FallbackDisplayCalibration(),
                 batteryCycleCount: Int? = nil,
                 batteryHealthPercent: Int? = nil,
                 wattHoursPerPercent: Double? = nil) {
        self.display = display
        self.batteryCycleCount = batteryCycleCount
        self.batteryHealthPercent = batteryHealthPercent
        self.wattHoursPerPercent = wattHoursPerPercent
    }

    /// Watt-hours corresponding to a battery-percentage drop.
    package func wattHours(fromPercent percent: Int) -> Double? {
        guard let perPercent = wattHoursPerPercent, percent > 0 else { return nil }
        return Double(percent) * perPercent
    }

    /// The machine the application is running on.
    ///
    /// Still a lookup, but now one that happens *at the call site* rather than three levels down
    /// inside an arithmetic expression. Everything below this line takes what it is given.
    package static var current: MachineFacts {
        MachineFacts(display: DisplayCalibration.current,
                     batteryCycleCount: BatteryHardware.shared.cycleCount,
                     batteryHealthPercent: BatteryHardware.shared.healthPercent,
                     wattHoursPerPercent: BatteryHardware.shared.wattHoursPerPercent)
    }

    /// A machine with no battery and the fallback panel, for tests that do not care about either.
    package static let none = MachineFacts()
}
