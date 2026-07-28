import AppKit

/// Draws the cat used as an optional menu bar icon, awake and asleep.
///
/// Hand-drawn rather than an SF Symbol. `cat.fill` only exists from macOS 15 and this app supports
/// 14, and a symbol is one flat glyph — the tail and ears could not move on their own, which is
/// the whole idea here.
///
/// Everything is built for a **template image**: the silhouette is drawn solid and the eyes are
/// punched back out with `.clear`, so the menu bar's own tint fills the body and the holes read as
/// eyes in both light and dark menu bars. Painting white eyes instead would look correct on a dark
/// menu bar and turn into two white dots on a light one. Partial alpha tints proportionally, which
/// is what lets the sleep marks fade in and out.
///
/// The cat is deliberately **wide rather than tall**. The menu bar caps height at around 18pt but
/// does not care how much width an item takes, so bulk goes sideways: a big round head, a body
/// that flares to a flat base, and blunt rounded ears.
///
/// Sleeping is the same cat, not a second drawing — eyes shut, tail barely moving, and a couple of
/// marks drifting up beside its head. A separate curled-up pose was tried first and read as a
/// shapeless loaf at this size; keeping the familiar silhouette and closing the eyes is
/// unmistakable at a glance.
enum MenuBarCat {

    struct Pose {
        /// 0...1, phase of the wave travelling down the tail.
        var tailPhase: CGFloat
        /// -1...1, how far the ears lean to one side.
        var earSway: CGFloat = 0
        /// 0 = eyes open, 1 = fully shut.
        var blink: CGFloat = 0
        /// Shuts the eyes, calms the tail and draws the sleep marks.
        var asleep: Bool = false
        /// 0...1, how far the sleep marks have drifted along their loop.
        var sleepDrift: CGFloat = 0
    }

    /// Unit-space height of the drawing, base to ear tips.
    private static let artHeight: CGFloat = 19.0

    static func image(pose: Pose, height: CGFloat = 18, canvasWidth: CGFloat = 30,
                      canvasHeight: CGFloat = 22) -> NSImage {
        let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }
        guard let context = NSGraphicsContext.current else { return image }
        context.imageInterpolation = .high
        context.cgContext.saveGState()

        let scale = height / artHeight
        context.cgContext.translateBy(x: canvasWidth / 2, y: (canvasHeight - height) / 2)
        context.cgContext.scaleBy(x: scale, y: scale)

        NSColor.black.setFill()
        drawTail(phase: pose.tailPhase, asleep: pose.asleep)
        drawBody()
        drawHead(earSway: pose.earSway)
        if pose.asleep { drawSleepMarks(drift: pose.sleepDrift) }
        punchEyes(blink: pose.blink, asleep: pose.asleep)

        context.cgContext.restoreGState()
        return image
    }

    // MARK: - Tail
    //
    // Coordinates are in a 19-tall space with the origin at the centre of the cat's base, y up.

    /// The tail as a **travelling wave** sampled along a spine, rather than one bezier whose
    /// control points slide about.
    ///
    /// Moving a single curve's control points swung the whole tail rigidly, like a hinged stick.
    /// A wave running from root to tip, with amplitude growing along the length, is what a tail
    /// actually does: the base stays put, the middle follows late, and the tip trails furthest.
    private static func drawTail(phase: CGFloat, asleep: Bool) {
        let samples = 20
        // Asleep the tail still moves, but barely — a completely still one looks like a stuck icon.
        //
        // Amplitude is modest and the tail is long: at 1.7 over a short spine the wave folded the
        // tail back across itself and the whole thing read as a bent arm rather than a tail.
        let amplitude: CGFloat = asleep ? 0.42 : 0.95
        let reach: CGFloat = asleep ? 6.0 : 9.6
        let root = CGPoint(x: 3.2, y: 0.7)

        func spine(_ s: CGFloat) -> CGPoint {
            CGPoint(x: root.x + 6.4 * pow(s, 0.7), y: root.y + reach * pow(s, 1.5))
        }

        var points: [CGPoint] = []
        for step in 0...samples {
            let s = CGFloat(step) / CGFloat(samples)
            let here = spine(s)
            let ahead = spine(min(s + 0.01, 1))

            // Perpendicular to the spine, so the wave displaces across the tail rather than
            // stretching it.
            var tx = ahead.x - here.x
            var ty = ahead.y - here.y
            let length = max(sqrt(tx * tx + ty * ty), 0.0001)
            tx /= length; ty /= length

            // A single wavelength along the tail: one clean S that travels to the tip. More than
            // one turned it into a squiggle at 18pt.
            let wave = CGFloat(sin(Double((1.0 * s - phase) * 2 * .pi)))
            let offset = amplitude * pow(s, 1.4) * wave
            points.append(CGPoint(x: here.x - ty * offset, y: here.y + tx * offset))
        }

        let path = NSBezierPath()
        path.lineWidth = 2.0
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: points[0])
        for point in points.dropFirst() { path.line(to: point) }
        path.stroke()
    }

    // MARK: - Body and head

    /// A round, heavy body: wide and flat where it meets the bar, bulging at the belly, tucking in
    /// to meet the head. The bulge is what makes it read as a chubby cat rather than a cone.
    private static func drawBody() {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: -5.5, y: 0))
        path.line(to: CGPoint(x: 5.5, y: 0))
        path.curve(to: CGPoint(x: 3.0, y: 7.2),
                   controlPoint1: CGPoint(x: 6.4, y: 3.2),
                   controlPoint2: CGPoint(x: 4.9, y: 6.3))
        path.line(to: CGPoint(x: -3.0, y: 7.2))
        path.curve(to: CGPoint(x: -5.5, y: 0),
                   controlPoint1: CGPoint(x: -4.9, y: 6.3),
                   controlPoint2: CGPoint(x: -6.4, y: 3.2))
        path.close()
        path.fill()
    }

    private static let headCentre = CGPoint(x: 0, y: 11.6)
    /// Big on purpose. A large head on a small body is most of what makes a drawing read as cute
    /// rather than merely accurate.
    private static let headRadius: CGFloat = 6.1

    /// Head and ears as one filled mass so no seam shows between them.
    private static func drawHead(earSway: CGFloat) {
        NSBezierPath(ovalIn: NSRect(x: headCentre.x - headRadius,
                                    y: headCentre.y - headRadius * 0.84,
                                    width: headRadius * 2, height: headRadius * 1.72)).fill()
        drawEar(side: -1, sway: earSway)
        drawEar(side: 1, sway: earSway)
    }

    /// A blunt, rounded ear that leans with `sway`.
    ///
    /// Both ears lean the same way, which reads as the whole head listening. An earlier version
    /// folded one ear flat instead; that looked less like a cat noticing something and more like
    /// it was wincing.
    ///
    /// Every vertex except the tip stays inside the head oval. Sitting one on the outline showed
    /// as a step in the silhouette — invisible while designing, obvious once drawn.
    private static func drawEar(side: CGFloat, sway: CGFloat) {
        let innerBase = CGPoint(x: headCentre.x + side * 1.6, y: headCentre.y + 3.4)
        let outerBase = CGPoint(x: headCentre.x + side * 5.1, y: headCentre.y + 1.7)
        // The tip leans sideways and dips a little on the way, so the ear pivots on its base
        // rather than sliding across the head.
        let lean = sway * 1.15
        let tip = CGPoint(x: headCentre.x + side * 4.9 + lean,
                          y: headCentre.y + 6.9 - abs(sway) * 0.35)

        let path = NSBezierPath()
        path.move(to: innerBase)
        path.curve(to: tip,
                   controlPoint1: CGPoint(x: innerBase.x + side * 0.2 + lean * 0.4,
                                          y: innerBase.y + 2.7),
                   controlPoint2: CGPoint(x: tip.x - side * 1.6, y: tip.y - 0.7))
        path.curve(to: outerBase,
                   controlPoint1: CGPoint(x: tip.x + side * 1.5, y: tip.y - 0.6),
                   controlPoint2: CGPoint(x: outerBase.x + side * 0.9, y: outerBase.y + 2.5))
        path.close()
        path.fill()
    }

    // MARK: - Face

    /// Eyes, punched out of the silhouette so the menu bar shows through them.
    ///
    /// Awake they are wide-set ovals looking straight ahead. Asleep they become shallow downward
    /// arcs — a flat line reads as a squint, a curve reads as contentment.
    private static func punchEyes(blink: CGFloat, asleep: Bool) {
        NSGraphicsContext.current?.compositingOperation = .clear
        defer { NSGraphicsContext.current?.compositingOperation = .sourceOver }

        let y: CGFloat = 12.2
        guard !asleep else {
            NSColor.black.setStroke()
            for side in [CGFloat(-1), 1] {
                let centre = CGPoint(x: side * 2.5, y: y)
                let arc = NSBezierPath()
                arc.lineWidth = 0.8
                arc.lineCapStyle = .round
                arc.move(to: CGPoint(x: centre.x - 1.2, y: centre.y + 0.45))
                arc.curve(to: CGPoint(x: centre.x + 1.2, y: centre.y + 0.45),
                          controlPoint1: CGPoint(x: centre.x - 0.6, y: centre.y - 0.8),
                          controlPoint2: CGPoint(x: centre.x + 0.6, y: centre.y - 0.8))
                arc.stroke()
            }
            return
        }

        let open = 1 - min(max(blink, 0), 1)
        let width: CGFloat = 1.95
        let height = max(0.4, 2.3 * open)
        for side in [CGFloat(-1), 1] {
            let rect = NSRect(x: side * 2.5 - width / 2, y: y - height / 2,
                              width: width, height: height)
            NSBezierPath(roundedRect: rect, xRadius: width / 2, yRadius: height / 2).fill()
        }
    }

    /// Two "z" marks drifting up and away from the head, half a loop apart.
    ///
    /// They live in the spare width beside the cat, because the menu bar has no height to spare
    /// above it. Drawn as strokes rather than text: at this size a font glyph is a smudge, while
    /// three straight lines still read as a z.
    private static func drawSleepMarks(drift: CGFloat) {
        for index in 0..<2 {
            var t = drift + CGFloat(index) * 0.5
            t -= floor(t)

            let size = 1.4 + t * 1.5
            let origin = CGPoint(x: 6.6 + t * 2.4, y: 11.0 + t * 5.4)
            // Fades up from nothing and back out, so a mark never pops into or out of existence.
            let alpha = CGFloat(sin(Double(t) * .pi))
            guard alpha > 0.02 else { continue }

            NSColor.black.withAlphaComponent(alpha).setStroke()
            let z = NSBezierPath()
            z.lineWidth = 0.66
            z.lineCapStyle = .round
            z.lineJoinStyle = .round
            z.move(to: CGPoint(x: origin.x, y: origin.y + size))
            z.line(to: CGPoint(x: origin.x + size, y: origin.y + size))
            z.line(to: CGPoint(x: origin.x, y: origin.y))
            z.line(to: CGPoint(x: origin.x + size, y: origin.y))
            z.stroke()
        }
        NSColor.black.setFill()
    }
}
