import AppKit

/// Draws the sitting cat used as an optional menu bar icon.
///
/// Hand-drawn rather than an SF Symbol. `cat.fill` only exists from macOS 15 and this app supports
/// 14, and a symbol is one flat glyph — the tail could not be animated on its own, which is the
/// whole idea here.
///
/// Everything is built for a **template image**: the silhouette is drawn solid and the eyes are
/// punched back out with `.clear`, so the menu bar's own tint fills the body and the holes read as
/// eyes in both light and dark menu bars. Painting white eyes instead would look correct on a dark
/// menu bar and turn into two white dots on a light one.
///
/// At 18pt tall almost nothing survives, so the shapes are deliberately coarse: a round head, two
/// wide ears, a body that flares to a flat base so the cat looks *seated on* the bar rather than
/// floating above it, and a tail thick enough not to disappear.
enum MenuBarCat {

    /// One drawn pose.
    struct Pose {
        /// -1...1, how far the tail is swung to the side.
        var tail: CGFloat
        /// 0 = open, 1 = fully shut.
        var blink: CGFloat
    }

    /// Total height of the drawing in unit space, from the base to the ear tips.
    private static let artHeight: CGFloat = 17.0

    /// Renders a pose into a template image the status bar can tint.
    ///
    /// `canvas` is bigger than the cat so the tail's outermost swing is not clipped; the drawing
    /// is anchored to the bottom of that canvas so the cat keeps sitting on the same line while
    /// the tail moves.
    static func image(pose: Pose, height: CGFloat = 16, canvas: CGFloat = 22) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }
        guard let context = NSGraphicsContext.current else { return image }
        context.imageInterpolation = .high
        context.cgContext.saveGState()

        // Work in a unit space scaled to the requested height, so the proportions below read as
        // fractions of the cat rather than as pixel values. `artHeight` is the real extent of the
        // drawing, ear tips included — dividing by a round 16 instead made the cat 7% taller than
        // asked for, which is how a menu bar icon ends up clipped.
        let scale = height / artHeight
        let baseline = (canvas - height) / 2      // the line the cat sits on
        context.cgContext.translateBy(x: canvas / 2, y: baseline)
        context.cgContext.scaleBy(x: scale, y: scale)

        NSColor.black.setFill()
        drawTail(pose.tail)
        drawBody()
        drawHead()
        punchEyes(blink: pose.blink)

        context.cgContext.restoreGState()
        return image
    }

    // MARK: - Parts
    //
    // Coordinates are in a 16-tall space with the origin at the centre of the cat's base, y up.

    /// The tail: a thick stroked curve leaving the cat's right hip, sweeping out and curling up.
    /// Stroked rather than filled so the width stays even along the whole sweep, and round-capped
    /// so the tip does not look cut off.
    private static func drawTail(_ swing: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = 1.9
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // The base stays put — a tail that slides around the hip reads as a detached worm.
        let start = CGPoint(x: 3.0, y: 0.9)
        // Held clear of the body across the whole sweep. Centred on the body edge, the inward
        // extreme tucked against the flank and simply vanished at menu bar size.
        let tipX = 7.0 + swing * 1.3
        let tipY = 7.6 + abs(swing) * -1.0
        path.move(to: start)
        path.curve(to: CGPoint(x: tipX, y: tipY),
                   controlPoint1: CGPoint(x: 6.6 + swing * 0.6, y: 0.5),
                   controlPoint2: CGPoint(x: 7.9 + swing * 1.2, y: 4.2))
        path.stroke()
    }

    /// Body: a rounded wedge, wide and flat at the floor, narrowing towards the shoulders.
    private static func drawBody() {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: -4.3, y: 0))
        path.line(to: CGPoint(x: 4.3, y: 0))
        // Shoulders curve inward to meet the head.
        path.curve(to: CGPoint(x: 2.5, y: 7.2),
                   controlPoint1: CGPoint(x: 4.5, y: 4.2),
                   controlPoint2: CGPoint(x: 3.6, y: 6.6))
        path.line(to: CGPoint(x: -2.5, y: 7.2))
        path.curve(to: CGPoint(x: -4.3, y: 0),
                   controlPoint1: CGPoint(x: -3.6, y: 6.6),
                   controlPoint2: CGPoint(x: -4.5, y: 4.2))
        path.close()
        path.fill()
    }

    /// Head plus ears, as one filled shape so no seam shows between them.
    private static func drawHead() {
        let centre = CGPoint(x: 0, y: 10.6)
        let radius: CGFloat = 4.5

        let head = NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius * 0.92,
                                               width: radius * 2, height: radius * 1.84))
        head.fill()

        // Every ear vertex except the tip stays *inside* the head oval. Sitting the outer base on
        // the outline at x = 4.4 put it 0.1 past the curve, which showed as a small step on the
        // silhouette — the kind of flaw that is invisible while designing and obvious once drawn.
        for side in [CGFloat(-1), 1] {
            let ear = NSBezierPath()
            ear.move(to: CGPoint(x: side * 1.4, y: centre.y + 2.4))
            ear.line(to: CGPoint(x: side * 4.0, y: centre.y + 6.4))
            ear.line(to: CGPoint(x: side * 4.0, y: centre.y + 1.0))
            ear.close()
            ear.fill()
        }
    }

    /// Eyes, punched out of the silhouette so the menu bar shows through them.
    ///
    /// Two round eyes facing straight ahead — the cat is meant to be looking back at you. A blink
    /// squashes them towards a line instead of shrinking them, which is what a closing eyelid
    /// actually looks like.
    private static func punchEyes(blink: CGFloat) {
        NSGraphicsContext.current?.compositingOperation = .clear
        defer { NSGraphicsContext.current?.compositingOperation = .sourceOver }

        let open = 1 - min(max(blink, 0), 1)
        let width: CGFloat = 1.55
        let height = max(0.34, 1.75 * open)
        let y: CGFloat = 11.1

        for side in [CGFloat(-1), 1] {
            let rect = NSRect(x: side * 2.05 - width / 2, y: y - height / 2,
                              width: width, height: height)
            // Fully closed reads better as a soft line than as a flat rectangle.
            NSBezierPath(roundedRect: rect, xRadius: width / 2, yRadius: height / 2).fill()
        }
    }
}
