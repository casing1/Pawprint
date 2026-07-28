import AppKit

/// Draws the cat used as an optional menu bar icon, awake and asleep.
///
/// Hand-drawn rather than an SF Symbol. `cat.fill` only exists from macOS 15 and this app supports
/// 14, and a symbol is one flat glyph — neither the tail nor an ear could be moved on its own,
/// which is the whole idea here.
///
/// Everything is built for a **template image**: the silhouette is drawn solid and the eyes are
/// punched back out with `.clear`, so the menu bar's own tint fills the body and the holes read as
/// eyes in both light and dark menu bars. Painting white eyes instead would look correct on a dark
/// menu bar and turn into two white dots on a light one.
///
/// The cat is deliberately **wide rather than tall**. The menu bar caps height at around 18pt but
/// does not care how much width an item takes, so bulk goes sideways: a round head nearly as wide
/// as the body, a body that flares to a flat base, and blunt rounded ears. An earlier, slimmer
/// version was correct at 8x and nearly invisible at actual size.
enum MenuBarCat {

    /// The awake, sitting pose.
    struct Pose {
        /// -1...1, how far the tail is swung to the side.
        var tail: CGFloat
        /// 0 = eyes open, 1 = fully shut.
        var blink: CGFloat
        /// 0 = both ears up, 1 = the left ear folded right over.
        var earFold: CGFloat = 0
    }

    /// Unit-space height of the sitting drawing, base to ear tips.
    private static let artHeight: CGFloat = 18.4
    /// The sleeping drawing is genuinely shorter than the sitting one, so it gets its own height
    /// and is scaled to fill the same icon. Scaled by the sitting height it came out as a flat
    /// sliver along the bottom of the canvas — accurate, and far too small to recognise.
    private static let sleepArtHeight: CGFloat = 12.6

    // MARK: - Entry points

    /// The awake cat, sitting and looking at you.
    static func image(pose: Pose, height: CGFloat = 17, canvasWidth: CGFloat = 26,
                      canvasHeight: CGFloat = 22) -> NSImage {
        render(width: canvasWidth, height: canvasHeight, drawnHeight: height) {
            drawTail(pose.tail)
            drawBody()
            drawHead(earFold: pose.earFold)
            punchEyes(blink: pose.blink)
        }
    }

    /// The sleeping cat: curled on its side, eyes shut, breathing.
    ///
    /// Replaces simply freezing the sitting pose when nothing is happening. A motionless upright
    /// cat reads as a stuck icon; a curled one reads as a cat with nothing to do.
    static func sleepingImage(breath: CGFloat, height: CGFloat = 17, canvasWidth: CGFloat = 26,
                              canvasHeight: CGFloat = 22) -> NSImage {
        render(width: canvasWidth, height: canvasHeight, drawnHeight: height,
               artHeight: sleepArtHeight) {
            drawSleeping(breath: breath)
        }
    }

    /// Shared setup: a unit space with the origin on the cat's baseline, scaled so `drawnHeight`
    /// is the true height of the art — ear tips included.
    private static func render(width: CGFloat, height: CGFloat, drawnHeight: CGFloat,
                               artHeight: CGFloat = MenuBarCat.artHeight,
                               body: () -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }
        guard let context = NSGraphicsContext.current else { return image }
        context.imageInterpolation = .high
        context.cgContext.saveGState()

        let scale = drawnHeight / artHeight
        context.cgContext.translateBy(x: width / 2, y: (height - drawnHeight) / 2)
        context.cgContext.scaleBy(x: scale, y: scale)

        NSColor.black.setFill()
        body()

        context.cgContext.restoreGState()
        return image
    }

    // MARK: - Awake
    //
    // Coordinates are in an 18.4-tall space with the origin at the centre of the cat's base, y up.

    /// A thick stroked curve leaving the right hip and curling up. Stroked rather than filled so
    /// the width stays even along the sweep, and round-capped so the tip is not cut off.
    private static func drawTail(_ swing: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = 2.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // The base stays put — a tail that slides around the hip reads as a detached worm. The
        // whole sweep is held clear of the flank, since the inward extreme used to tuck against
        // the body and vanish at menu bar size.
        path.move(to: CGPoint(x: 3.6, y: 0.9))
        path.curve(to: CGPoint(x: 8.4 + swing * 1.4, y: 8.2 + abs(swing) * -1.1),
                   controlPoint1: CGPoint(x: 8.0 + swing * 0.6, y: 0.5),
                   controlPoint2: CGPoint(x: 9.4 + swing * 1.3, y: 4.4))
        path.stroke()
    }

    /// A round, heavy body: wide and flat where it meets the bar, bulging at the belly, tucking in
    /// to meet the head. The bulge is what makes it read as a chubby cat rather than a cone.
    private static func drawBody() {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: -5.5, y: 0))
        path.line(to: CGPoint(x: 5.5, y: 0))
        path.curve(to: CGPoint(x: 3.1, y: 7.6),
                   controlPoint1: CGPoint(x: 6.4, y: 3.4),
                   controlPoint2: CGPoint(x: 5.0, y: 6.6))
        path.line(to: CGPoint(x: -3.1, y: 7.6))
        path.curve(to: CGPoint(x: -5.5, y: 0),
                   controlPoint1: CGPoint(x: -5.0, y: 6.6),
                   controlPoint2: CGPoint(x: -6.4, y: 3.4))
        path.close()
        path.fill()
    }

    /// Head and ears as one filled mass so no seam shows between them.
    private static func drawHead(earFold: CGFloat) {
        let centre = CGPoint(x: 0, y: 11.4)
        let radius: CGFloat = 5.5

        NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius * 0.86,
                                    width: radius * 2, height: radius * 1.78)).fill()

        // The left ear folds; the right stays up.
        drawEar(centre: centre, side: -1, fold: earFold)
        drawEar(centre: centre, side: 1, fold: 0)
    }

    /// A blunt, rounded ear. `fold` collapses it sideways over the head, the way a cat flicks one
    /// ear back without moving the other.
    ///
    /// Both base corners stay inside the head oval. Sitting one on the outline showed as a step in
    /// the silhouette — invisible while designing, obvious once drawn.
    private static func drawEar(centre: CGPoint, side: CGFloat, fold: CGFloat) {
        let f = min(max(fold, 0), 1)

        let innerBase = CGPoint(x: centre.x + side * 1.5, y: centre.y + 3.0)
        let outerBase = CGPoint(x: centre.x + side * 4.7, y: centre.y + 1.4)
        // Upright the tip stands above the head; folded it drops and swings inward.
        let tip = CGPoint(x: centre.x + side * (4.6 - f * 1.4),
                          y: centre.y + 6.6 - f * 4.6)

        let path = NSBezierPath()
        path.move(to: innerBase)
        // Rounded rather than pointed: two curves meeting at a blunt tip.
        path.curve(to: tip,
                   controlPoint1: CGPoint(x: innerBase.x + side * 0.2, y: innerBase.y + 2.6),
                   controlPoint2: CGPoint(x: tip.x - side * 1.5, y: tip.y - 0.6))
        path.curve(to: outerBase,
                   controlPoint1: CGPoint(x: tip.x + side * 1.4, y: tip.y - 0.5),
                   controlPoint2: CGPoint(x: outerBase.x + side * 0.9, y: outerBase.y + 2.4))
        path.close()
        path.fill()
    }

    /// Eyes, punched out of the silhouette so the menu bar shows through them.
    ///
    /// Wide-set and round — the cat is meant to be looking back at you. A blink squashes them
    /// towards a line rather than shrinking them, which is what an eyelid actually does.
    private static func punchEyes(blink: CGFloat) {
        NSGraphicsContext.current?.compositingOperation = .clear
        defer { NSGraphicsContext.current?.compositingOperation = .sourceOver }

        let open = 1 - min(max(blink, 0), 1)
        let width: CGFloat = 1.85
        let height = max(0.38, 2.15 * open)
        let y: CGFloat = 11.9

        for side in [CGFloat(-1), 1] {
            let rect = NSRect(x: side * 2.35 - width / 2, y: y - height / 2,
                              width: width, height: height)
            NSBezierPath(roundedRect: rect, xRadius: width / 2, yRadius: height / 2).fill()
        }
    }

    // MARK: - Asleep

    /// Curled on the baseline: a low mound of body with the head tucked against it on the left,
    /// ears flattened back, and the tail wrapped around the front.
    ///
    /// `breath` is 0...1 over one slow inhale, and lifts the body a little. The movement is tiny on
    /// purpose — enough to show the icon is alive, not enough to catch the eye.
    private static func drawSleeping(breath: CGFloat) {
        let rise = sin(Double(min(max(breath, 0), 1)) * 2 * .pi)
        let lift = CGFloat(rise) * 0.45

        // Curled body: a broad rounded mound, highest behind the shoulders. Drawn first so the
        // head and ears can sit proud of it.
        // Shifted right of centre: the head hangs off the left end, and at the old offset its
        // outermost curve sat about a pixel from the canvas edge and read as a flat cut.
        let body = NSBezierPath()
        body.move(to: CGPoint(x: -6.6, y: 0))
        body.curve(to: CGPoint(x: 9.0, y: 0),
                   controlPoint1: CGPoint(x: -6.2, y: 11.0 + lift),
                   controlPoint2: CGPoint(x: 10.4, y: 8.6 + lift))
        body.close()
        body.fill()

        // Head tucked at the left, deliberately overhanging the body's edge so its curve shows in
        // the silhouette. Buried inside the mound it read as one shapeless loaf.
        let headCentre = CGPoint(x: -4.5, y: 4.2)
        let radius: CGFloat = 4.3
        NSBezierPath(ovalIn: NSRect(x: headCentre.x - radius, y: headCentre.y - radius * 0.9,
                                    width: radius * 2, height: radius * 1.8)).fill()

        // Ears, laid back but still breaking the head's outline — an ear that does not clear the
        // silhouette is an ear nobody can see.
        for (dx, dy, lean) in [(CGFloat(-2.6), CGFloat(2.6), CGFloat(-1)),
                               (CGFloat(0.6), CGFloat(3.1), CGFloat(1))] {
            let base = CGPoint(x: headCentre.x + dx, y: headCentre.y + dy)
            let ear = NSBezierPath()
            ear.move(to: CGPoint(x: base.x - 1.5, y: base.y - 0.9))
            ear.curve(to: CGPoint(x: base.x + 1.6, y: base.y - 1.1),
                      controlPoint1: CGPoint(x: base.x - 1.0 + lean * 0.4, y: base.y + 2.3),
                      controlPoint2: CGPoint(x: base.x + 1.4 + lean * 0.4, y: base.y + 1.9))
            ear.close()
            ear.fill()
        }

        // Tail curled out past the right flank and back along the floor, so it is visible against
        // the background rather than lost inside the body.
        let tail = NSBezierPath()
        tail.lineWidth = 2.0
        tail.lineCapStyle = .round
        tail.lineJoinStyle = .round
        tail.move(to: CGPoint(x: 7.2, y: 1.2))
        tail.curve(to: CGPoint(x: 3.0, y: 1.1),
                   controlPoint1: CGPoint(x: 12.2, y: 2.2),
                   controlPoint2: CGPoint(x: 8.8, y: -2.2))
        tail.stroke()

        // A closed eye: a shallow downward arc, punched out like the awake eyes.
        NSGraphicsContext.current?.compositingOperation = .clear
        defer { NSGraphicsContext.current?.compositingOperation = .sourceOver }
        let eye = NSBezierPath()
        eye.lineWidth = 0.72
        eye.lineCapStyle = .round
        eye.move(to: CGPoint(x: headCentre.x - 2.0, y: headCentre.y + 0.6))
        eye.curve(to: CGPoint(x: headCentre.x + 0.2, y: headCentre.y + 0.6),
                  controlPoint1: CGPoint(x: headCentre.x - 1.4, y: headCentre.y - 0.7),
                  controlPoint2: CGPoint(x: headCentre.x - 0.4, y: headCentre.y - 0.7))
        eye.stroke()
    }
}
