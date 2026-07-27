import AppKit
import CoreGraphics

/// Real physical calibration for the "커서가 N미터 이동" / "화면 N개 높이만큼 스크롤" conversions.
///
/// These were previously hardcoded guesses, which over-reported by ~50% on a Retina MacBook.
/// Now derived from the actual display: `CGDisplayScreenSize` reports the panel's physical size
/// in millimeters, which combined with its size in points gives a true points-per-meter scale.
/// Values are cached and recomputed when the screen configuration changes.
final class DisplayMetrics {
    static let shared = DisplayMetrics()

    /// Fallbacks for displays that don't report a physical size (common for virtual displays
    /// and some capture cards, where `CGDisplayScreenSize` returns zero).
    private enum Fallback {
        static let pointsPerMeter: Double = 5200
        static let screenHeightPoints: Double = 900
    }

    /// How many points correspond to one physical meter of desk-surface cursor travel.
    private(set) var pointsPerMeter: Double = Fallback.pointsPerMeter

    /// Height of the main display in points — one "screen" of scrolling.
    private(set) var mainScreenHeightPoints: Double = Fallback.screenHeightPoints

    /// Physical height of the main display in meters, used for the "scrolled a building's
    /// height" style conversions.
    private(set) var mainScreenHeightMeters: Double = 0.2

    private var observer: NSObjectProtocol?

    private init() {
        recompute()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recompute()
        }
    }

    func recompute() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let heightPoints = Double(screen.frame.height)
        if heightPoints > 0 {
            mainScreenHeightPoints = heightPoints
        }

        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        let physicalMM = CGDisplayScreenSize(displayID)
        guard physicalMM.width > 0, physicalMM.height > 0 else { return }

        pointsPerMeter = Double(screen.frame.width) / (Double(physicalMM.width) / 1000.0)
        mainScreenHeightMeters = Double(physicalMM.height) / 1000.0
    }

    /// Converts accumulated cursor-delta points into meters of physical movement.
    func meters(fromPoints points: Double) -> Double {
        points / pointsPerMeter
    }

    /// Converts accumulated scroll points into "screens worth of content".
    func screens(fromScrollPoints points: Double) -> Double {
        points / mainScreenHeightPoints
    }
}
