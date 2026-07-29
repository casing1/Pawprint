import AppKit
import Observation
import SwiftUI
import PawprintCore

/// Drives the menu bar icon animation, for whichever icon the user picked.
///
/// The frames are **pre-rendered `NSImage`s**, not SwiftUI transforms. `MenuBarExtra` rasterizes
/// its label into a template image, and geometry modifiers (`rotationEffect`, `offset`,
/// `scaleEffect`) applied inside that label don't survive the trip — the icon simply sat still.
/// Swapping the image itself is the one thing the menu bar reliably re-renders.
@Observable
@MainActor
final class MenuBarIconAnimator {
    static let shared = MenuBarIconAnimator()

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

    /// One cycle: one paw wiggle, or one tail wave. Both icons share the frame clock, so keeping
    /// them to one motion per cycle is what makes them move at the same pace.
    ///
    /// Doubled from 24 with the per-frame intervals halved to match, so each cycle takes the same
    /// time as before at twice the frame rate. At 24 the slow end of the range was three frames a
    /// second, and the sway visibly stepped.
    static let frameCount = 48
    /// Point size of the rendered glyph. Menu bar icons are ~18pt tall.
    private static let glyphSize: CGFloat = 16
    /// Canvas is larger than the glyph so rotated corners aren't clipped.
    private static let canvasSize: CGFloat = 22

    /// Wiggle poses: a soft sine sway plus a bob, so it eases at the extremes instead of ticking
    /// like a metronome.
    ///
    /// Divided by `frameCount`, like the cat. It used to divide by 12 — a leftover from when the
    /// cycle *was* 12 frames — so when the cycle was lengthened for the cat, the paw kept its old
    /// rhythm and ran four wiggles for every one of the cat's tail waves. Side by side the paw
    /// looked frantic next to the same app's other icon.
    private static let angles: [CGFloat] = (0..<frameCount).map { step in
        let t = Double(step) / Double(frameCount) * 2 * .pi
        return CGFloat(sin(t) * 9)
    }
    private static let bobs: [CGFloat] = (0..<frameCount).map { step in
        let t = Double(step) / Double(frameCount) * 2 * .pi
        return CGFloat(-abs(sin(t * 2)) * 1.1)
    }

    /// Cat poses: one unhurried tail sweep per cycle, with a blink near the end of it.
    ///
    /// The blink is two frames out of twenty-four rather than a fixed interval in seconds, so it
    /// speeds up along with everything else — a cat blinking at a constant rate while its tail
    /// whips about looks broken.
    static let catPoses: [MenuBarCat.Pose] = (0..<frameCount).map { step in
        let p = Double(step) / Double(frameCount)
        return MenuBarCat.Pose(tailPhase: CGFloat(p),
                               // Ears sway at half the tail's rate and a quarter turn behind it,
                               // so the two motions never line up into one rocking motion.
                               earSway: CGFloat(sin((p - 0.25) * 2 * .pi) * 0.55),
                               blink: blinkCurve(at: p))
    }

    /// Sleeping frames: the same cat with its eyes shut, a barely-moving tail, and the marks
    /// drifting. Its own array because it advances on a much slower clock.
    static let sleepPoses: [MenuBarCat.Pose] = (0..<sleepFrameCount).map { step in
        let p = Double(step) / Double(sleepFrameCount)
        return MenuBarCat.Pose(tailPhase: CGFloat(p),
                               earSway: CGFloat(sin(p * 2 * .pi) * 0.22),
                               blink: 1,
                               asleep: true,
                               sleepDrift: CGFloat(p))
    }

    /// A smooth blink once per cycle: a raised cosine over a short window rather than a couple of
    /// hand-picked frames, which snapped shut and open again.
    private static func blinkCurve(at p: Double) -> CGFloat {
        let centre = 0.86
        let halfWidth = 0.055
        let distance = abs(p - centre)
        guard distance < halfWidth else { return 0 }
        return CGFloat((cos(distance / halfWidth * .pi) + 1) / 2)
    }

    static let sleepFrameCount = 48
    private static let sleepFrames: [NSImage] = sleepPoses.map {
        MenuBarCat.image(pose: $0, height: catHeight,
                         canvasWidth: catCanvasWidth, canvasHeight: canvasSize)
    }

    /// One full drift of the sleep marks every ~13s: about four image swaps a second while the
    /// user is away, against forty while typing. The timer that used to stop entirely now just
    /// slows right down.
    private static let sleepInterval: TimeInterval = 0.28

    /// The menu bar caps height at about 18pt but does not care about width, so the cat is drawn
    /// at the height limit and given a wider canvas to be bulky in. At 17pt in a square canvas it
    /// was legible but small next to the paw.
    static let catHeight: CGFloat = 19
    /// Wide enough for the tail's full sweep on one side and the sleep marks on the other.
    static let catCanvasWidth: CGFloat = 38

    let filledFrames: [NSImage]
    let restingImage: NSImage
    private let catFrames: [NSImage]
    private let catResting: NSImage

    private init() {
        filledFrames = (0..<Self.frameCount).map {
            Self.renderPaw(symbol: "pawprint.fill", angle: Self.angles[$0], dy: Self.bobs[$0])
        }
        restingImage = Self.renderPaw(symbol: "pawprint", angle: 0, dy: 0)
        catFrames = Self.catPoses.map {
            MenuBarCat.image(pose: $0, height: Self.catHeight,
                             canvasWidth: Self.catCanvasWidth, canvasHeight: Self.canvasSize)
        }
        catResting = Self.sleepFrames[0]
    }

    private var style: MenuBarIconStyle { ActivityCenter.shared.settings.menuBarIcon }

    /// True while the icon should be showing the idle state rather than the active animation.
    @ObservationIgnored private var isSleeping = false

    var currentImage: NSImage {
        guard style == .cat else {
            guard ActivityCenter.shared.isRecordingActive else { return restingImage }
            return filledFrames[frame % filledFrames.count]
        }
        // The cat curls up and breathes instead of freezing — both when recording is paused and
        // when the user has simply gone away.
        guard ActivityCenter.shared.isRecordingActive, !isSleeping else {
            return Self.sleepFrames[frame % Self.sleepFrames.count]
        }
        return catFrames[frame % catFrames.count]
    }

    /// Pushes the current icon out again. Needed when the chosen style changes: while parked there
    /// is no timer running at all, so a switch would otherwise not show until the next keystroke.
    func refreshIcon() {
        // Switching to the cat while idle has to start the breath; switching to the paw has to
        // stop it, or a paw would sit there ticking at the sleep rate for no reason.
        if isSleeping {
            if style == .cat {
                retime(to: Self.sleepInterval)
            } else {
                timer?.invalidate()
                timer = nil
                currentInterval = 0
                frame = 0
            }
        }
        onFrame?(currentImage)
    }

    /// Every frame of a style's cycle, for the README animations. Same images the menu bar shows.
    static func animationFrames(for style: MenuBarIconStyle, asleep: Bool) -> [NSImage] {
        switch style {
        case .paw:
            return asleep ? [shared.restingImage] : shared.filledFrames
        case .cat:
            return asleep ? sleepPoses.map(catImage) : catPoses.map(catImage)
        }
    }

    private static func catImage(_ pose: MenuBarCat.Pose) -> NSImage {
        MenuBarCat.image(pose: pose, height: catHeight,
                         canvasWidth: catCanvasWidth, canvasHeight: canvasSize)
    }

    /// Seconds per frame at a typing pace, for the README animations.
    static let showcaseInterval: TimeInterval = 0.05

    /// A representative still of a style, for the Settings picker.
    static func previewImage(for style: MenuBarIconStyle) -> NSImage {
        switch style {
        case .paw:
            return renderPaw(symbol: "pawprint.fill", angle: 0, dy: 0)
        case .cat:
            return MenuBarCat.image(pose: .init(tailPhase: 0.12), height: catHeight,
                                    canvasWidth: catCanvasWidth, canvasHeight: canvasSize)
        }
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
        isSleeping = false
        retime(to: interval(forWPM: liveWPM))
    }

    /// Idle state. The paw settles and the timer stops outright; the cat lies down and keeps
    /// breathing, which is the whole point of having a sleeping pose rather than a frozen one.
    private func park() {
        let wasSleeping = isSleeping
        isSleeping = true
        if style == .cat {
            frame = 0
            onFrame?(currentImage)
            retime(to: Self.sleepInterval)
            return
        }
        guard timer != nil || frame != 0 || !wasSleeping else { return }
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
        case 70...: return 0.021
        case 45..<70: return 0.028
        case 25..<45: return 0.038
        case 10..<25: return 0.052
        case 1..<10: return 0.072
        default: return 0.10      // idle sway — still alive, just lazy
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
