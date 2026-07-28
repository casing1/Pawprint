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
    /// Widens everything without making it taller.
    private static let xStretch: CGFloat = 1.1

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

        // Stretched horizontally: the menu bar limits height but not width, so the cat gets a
        // little wider than it is tall. Shifted left of centre because everything that hangs off
        // the silhouette — the tail, the sleep marks — hangs off the right, and centring the
        // canvas on the body alone left the cat looking pushed to one side.
        let scale = height / artHeight
        context.cgContext.translateBy(x: canvasWidth / 2 - 2.2 * scale * xStretch,
                                      y: (canvasHeight - height) / 2)
        context.cgContext.scaleBy(x: scale * xStretch, y: scale)

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
        let samples = 30
        // Asleep the tail still moves, but barely — a completely still one looks like a stuck icon.
        let amplitude: CGFloat = asleep ? 0.7 : 1.55

        // The whole tail leans as well as rippling. The travelling wave alone only nudges the
        // outline sideways, which is legible at 8x and almost invisible at 19pt — swinging the
        // tip through a real arc is what makes the movement read at menu bar size.
        // Biased outward by a sixth of the swing. Centred on the resting position, the inward
        // extreme pressed the tail against the flank and the gap between them closed into what
        // looked like a loop; the arc is the same size, just shifted clear of the body.
        let sweep = (CGFloat(sin(Double(phase) * 2 * .pi)) + 0.18) * (asleep ? 0.35 : 1)

        // The spine is a cubic bezier, evaluated directly. Trigonometric and power curves both
        // fought the shape wanted here: a gentle S that leaves the hip, sweeps out and up, and
        // curls back at the tip. A bezier states that shape outright, and being a polynomial its
        // derivative is continuous, so there is no point along it that can pinch into a corner.
        //
        // The root sits *inside* the body at haunch height, so the body hides the first third and
        // the tail appears from behind the cat — which is where a tail comes from.
        //
        // Height matters as much as the root. Rooted at the feet it emerged beside the front paws
        // and read as an arm reaching down; swept up to head height it read as an arm raised. It
        // now leaves low, at the hip, and rises well to the right of the head rather than beside
        // it, so nothing about it can be mistaken for a limb.
        let p0 = CGPoint(x: 1.0, y: 2.0)
        let p1 = CGPoint(x: 6.5, y: 1.1)
        let p2 = CGPoint(x: (asleep ? 10.4 : 11.2) + sweep * 1.3,
                         y: asleep ? 3.0 : 5.0)
        // The tip travels furthest and dips a little at the extremes, the way a tail loses height
        // as it swings out.
        let p3 = CGPoint(x: (asleep ? 9.2 : 9.6) + sweep * 2.6,
                         y: (asleep ? 6.2 : 11.2) - abs(sweep) * 0.8)

        func spine(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                           y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
        }

        var points: [CGPoint] = []
        for step in 0...samples {
            let s = CGFloat(step) / CGFloat(samples)
            let here = spine(s)
            let ahead = spine(min(s + 0.004, 1))

            var tx = ahead.x - here.x
            var ty = ahead.y - here.y
            let length = max(sqrt(tx * tx + ty * ty), 0.0001)
            tx /= length; ty /= length

            // Three quarters of a wavelength: one broad, unhurried S rather than a full sine,
            // which put two bends into a tail this short and read as a squiggle.
            let wave = CGFloat(sin(Double((0.75 * s - phase) * 2 * .pi)))
            let offset = amplitude * pow(s, 1.5) * wave
            points.append(CGPoint(x: here.x - ty * offset, y: here.y + tx * offset))
        }

        let path = NSBezierPath()
        path.lineWidth = 2.1
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        appendSmoothCurve(through: points, to: path)
        path.stroke()
    }

    /// Strokes a smooth curve through the sampled points, as a Catmull-Rom spline converted to
    /// cubic beziers.
    ///
    /// The samples used to be joined with straight lines. That is invisible where the tail is
    /// nearly straight and obvious where it bends hardest — the wave's peaks came out as distinct
    /// angular corners rather than an S. Raising the sample count alone only makes the corners
    /// smaller; interpolating between them is what removes them.
    private static func appendSmoothCurve(through points: [CGPoint], to path: NSBezierPath) {
        guard points.count > 2 else {
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.line(to: $0) }
            return
        }
        path.move(to: points[0])
        for index in 0..<(points.count - 1) {
            // The endpoints have no neighbour to look back or forward to, so they stand in for
            // themselves; the curve then starts and ends cleanly instead of overshooting.
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            path.curve(to: p2,
                       controlPoint1: CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                              y: p1.y + (p2.y - p0.y) / 6),
                       controlPoint2: CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                              y: p2.y - (p3.y - p1.y) / 6))
        }
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
