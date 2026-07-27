import AppKit
import Observation
import SwiftUI

/// Drives the menu bar paw animation.
///
/// The frames are **pre-rendered `NSImage`s**, not SwiftUI transforms. `MenuBarExtra` rasterizes
/// its label into a template image, and geometry modifiers (`rotationEffect`, `offset`,
/// `scaleEffect`) applied inside that label don't survive the trip — the icon simply sat still.
/// Swapping the image itself is the one thing the menu bar reliably re-renders.
@Observable
@MainActor
final class PawAnimator {
    static let shared = PawAnimator()

    /// Index into `filledFrames`.
    private(set) var frame: Int = 0

    /// Invoked on every frame so the status item can push the new image straight into its button.
    /// `MenuBarExtra`'s SwiftUI label did not reliably redraw on state change, so the menu bar
    /// icon is driven imperatively instead.
    @ObservationIgnored var onFrame: ((NSImage) -> Void)?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var currentInterval: TimeInterval = 0
    @ObservationIgnored private var tickCount = 0
    /// Set via the PAWPRINT_DEBUG_PAW env var to log tick/frame activity to stderr.
    @ObservationIgnored private let debugLogging = ProcessInfo.processInfo.environment["PAWPRINT_DEBUG_PAW"] != nil

    static let frameCount = 12
    /// Point size of the rendered glyph. Menu bar icons are ~18pt tall.
    private static let glyphSize: CGFloat = 16
    /// Canvas is larger than the glyph so rotated corners aren't clipped.
    private static let canvasSize: CGFloat = 22

    /// Wiggle poses: a soft sine sway plus a half-rate bob, so it eases at the extremes instead
    /// of ticking like a metronome.
    private static let angles: [CGFloat] = (0..<frameCount).map { step in
        let t = Double(step) / Double(frameCount) * 2 * .pi
        return CGFloat(sin(t) * 9)
    }
    private static let bobs: [CGFloat] = (0..<frameCount).map { step in
        let t = Double(step) / Double(frameCount) * 2 * .pi
        return CGFloat(-abs(sin(t * 2)) * 1.1)
    }

    let filledFrames: [NSImage]
    let restingImage: NSImage

    private init() {
        filledFrames = (0..<Self.frameCount).map {
            Self.renderPaw(symbol: "pawprint.fill", angle: Self.angles[$0], dy: Self.bobs[$0])
        }
        restingImage = Self.renderPaw(symbol: "pawprint", angle: 0, dy: 0)
    }

    var currentImage: NSImage {
        guard ActivityCenter.shared.isRecordingActive else { return restingImage }
        return filledFrames[frame % filledFrames.count]
    }

    // MARK: - Timing

    func start() {
        // Starts parked; the first input wakes it.
        onFrame?(currentImage)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = 0
    }

    /// How long without any input before the paw settles and the timer stops entirely. Animating
    /// while the user is away from the Mac costs battery for something nobody is looking at.
    private static let idleParkSeconds: TimeInterval = 30

    /// Re-evaluates the animation pace. Stops the timer outright once the user has been idle,
    /// and restarts it on the next sign of life.
    func updatePace(liveWPM: Double, isRecording: Bool, secondsSinceActivity: TimeInterval) {
        guard isRecording, secondsSinceActivity <= Self.idleParkSeconds else {
            park()
            return
        }
        retime(to: interval(forWPM: liveWPM))
    }

    /// Settles on a neutral pose and stops ticking.
    private func park() {
        guard timer != nil || frame != 0 else { return }
        timer?.invalidate()
        timer = nil
        currentInterval = 0
        frame = 0
        onFrame?(currentImage)
        if debugLogging {
            FileHandle.standardError.write("PAW parked (idle)\n".data(using: .utf8)!)
        }
    }

    private func interval(forWPM wpm: Double) -> TimeInterval {
        switch wpm {
        case 70...: return 0.055
        case 45..<70: return 0.075
        case 25..<45: return 0.10
        case 10..<25: return 0.15
        case 1..<10: return 0.22
        default: return 0.34      // idle sway — still alive, just lazy
        }
    }

    private func retime(to interval: TimeInterval) {
        guard abs(interval - currentInterval) > 0.005 else { return }
        currentInterval = interval
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        if debugLogging {
            FileHandle.standardError.write("PAW retime -> \(interval)s\n".data(using: .utf8)!)
        }
    }

    private func advance() {
        frame = (frame + 1) % Self.frameCount
        onFrame?(currentImage)
        tickCount += 1
        if debugLogging, tickCount % 20 == 0 {
            FileHandle.standardError.write(
                "PAW tick=\(tickCount) frame=\(frame) recording=\(ActivityCenter.shared.isRecordingActive)\n".data(using: .utf8)!
            )
        }
    }

    // MARK: - Frame rendering

    /// Draws the SF Symbol rotated about its centre into a template image the menu bar can tint.
    private static func renderPaw(symbol: String, angle: CGFloat, dy: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .regular)
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pawprint")?
            .withSymbolConfiguration(config) else {
            return NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        }

        let canvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        canvas.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
            let transform = NSAffineTransform()
            transform.translateX(by: canvasSize / 2, yBy: canvasSize / 2 + dy)
            transform.rotate(byDegrees: angle)
            transform.translateX(by: -base.size.width / 2, yBy: -base.size.height / 2)
            transform.concat()
            base.draw(
                at: .zero,
                from: NSRect(origin: .zero, size: base.size),
                operation: .sourceOver,
                fraction: 1
            )
        }
        canvas.unlockFocus()
        // Template images pick up the menu bar's tint (and invert correctly when highlighted).
        canvas.isTemplate = true
        return canvas
    }
}
