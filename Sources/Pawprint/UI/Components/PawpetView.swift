import SwiftUI
import PawprintCore

/// The day's cat, drawn procedurally from `PawpetTraits`.
///
/// This file is purely a renderer — every decision about *which* cat to draw lives in
/// `PawpetTraits`, so adding a new trait means adding a case there and a `draw…` branch here.
///
/// Drawing rules learned the hard way:
///  * **Eyes are always symmetric.** An early "chaotic" state gave the two eyes different pupil
///    sizes, which read as a rendering bug, not a mood.
///  * **Eyewear owns the eye region.** Sunglasses used to be painted over spiral eyes, leaving
///    ring fragments poking out around the lenses. Now the eye pass checks eyewear first.
///  * Chibi proportions (big head, small body, low-set big eyes) is what makes it cute; whiskers
///    and mouth lines are kept thin and faint because heavy face strokes turn "cat" into "insect".
@MainActor
struct PawpetView: View {
    let summary: DailySummary
    var size: CGFloat = 120
    var streakDays: Int = 0

    /// The aura wash reads as clutter at small sizes.
    var showsAura: Bool = true
    /// Draws these traits instead of deriving them from `summary`. Only the item catalog uses it,
    /// to show one item at a time on an otherwise neutral cat — there is no real day that wears a
    /// bandana and nothing else.
    var traitsOverride: PawpetTraits? = nil

    var traits: PawpetTraits {
        traitsOverride ?? PawpetTraits.forDay(summary, streakDays: streakDays)
    }

    var caption: String { traits.caption }

    var body: some View {
        let t = traits
        Canvas { context, canvasSize in
            draw(&context, canvasSize, t)
        }
        .frame(width: size, height: size)
        .background {
            if showsAura {
                RadialGradient(colors: t.auraColors.map { $0.opacity(0.30) } + [.clear],
                               center: .center, startRadius: 0, endRadius: size * 0.6)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
            }
        }
        .accessibilityLabel(L10n.t("pawpetView.00642d2d", t.caption))
    }

    // MARK: - Composition

    private func draw(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        let w = canvasSize.width
        let h = canvasSize.height
        // Chibi: the head fills most of the box; the body is a small base peeking out below.
        let headWidth = w * 0.60
        let headHeight = h * 0.52
        let headRect = CGRect(x: (w - headWidth) / 2, y: h * 0.26, width: headWidth, height: headHeight)

        drawBackdrop(&context, canvasSize, t)
        drawWings(&context, canvasSize, headRect, t)
        drawTail(&context, canvasSize, t)
        drawBody(&context, canvasSize, t)
        drawProp(&context, canvasSize, t)
        drawCollar(&context, canvasSize, t)
        drawCheekFluff(&context, headRect, t)
        drawEars(&context, headRect, t)
        drawHead(&context, headRect, t)
        drawPattern(&context, headRect, t)
        drawMuzzle(&context, headRect, t)
        drawEyes(&context, headRect, t)
        drawNoseAndMouth(&context, headRect, t)
        drawCheekMark(&context, headRect, t)
        drawWhiskers(&context, headRect, t)
        drawEyewear(&context, headRect, t)
        drawHeadwear(&context, headRect, t)
        drawPawCharm(&context, canvasSize, t)
        drawFloaters(&context, canvasSize, headRect, t)
        drawFrame(&context, canvasSize, t)
    }

    // MARK: - Head & body

    private func drawHead(_ context: inout GraphicsContext, _ rect: CGRect, _ t: PawpetTraits) {
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height * 0.48), with: .color(t.bodyColor))
    }

    /// Whitish patch behind the nose and mouth. Small thing, does a lot: it separates the face
    /// from the fur and is most of what reads as "plush toy" rather than "diagram".
    private func drawMuzzle(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        let width = head.width * 0.36
        let height = head.height * 0.24
        let rect = CGRect(x: head.midX - width / 2,
                          y: head.midY + head.height * 0.10,
                          width: width, height: height)
        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.30)))
    }

    private func drawCheekFluff(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        guard t.cheekFluff != .none else { return }
        // Small tufts at the jawline, mostly hidden behind the head — a silhouette detail,
        // not the growth-like blobs of the first attempt.
        let bumps = t.cheekFluff == .full ? 3 : 2
        let radius = head.width * (t.cheekFluff == .full ? 0.060 : 0.045)
        for side in [-1.0, 1.0] {
            for i in 0..<bumps {
                let cy = head.midY + head.height * (0.10 + CGFloat(i) * 0.10)
                let cx = head.midX + CGFloat(side) * (head.width * 0.485)
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                    with: .color(t.bodyColor)
                )
            }
        }
    }

    private func drawBody(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        let bodyWidth = canvasSize.width * 0.46
        let bodyHeight = canvasSize.height * 0.26
        let rect = CGRect(
            x: (canvasSize.width - bodyWidth) / 2,
            y: canvasSize.height * 0.72,
            width: bodyWidth,
            height: bodyHeight
        )
        context.fill(Path(roundedRect: rect, cornerRadius: bodyWidth * 0.40), with: .color(t.bodyColor))

        // Two small front paws with a toe line.
        for side in [-1.0, 1.0] {
            let pawWidth = bodyWidth * 0.24
            let pawHeight = pawWidth * 0.62
            let pawRect = CGRect(
                x: rect.midX + CGFloat(side) * bodyWidth * 0.20 - pawWidth / 2,
                y: rect.maxY - pawHeight * 1.05,
                width: pawWidth, height: pawHeight
            )
            context.fill(Path(ellipseIn: pawRect), with: .color(.white.opacity(0.35)))
            var toes = Path()
            toes.move(to: CGPoint(x: pawRect.midX, y: pawRect.midY))
            toes.addLine(to: CGPoint(x: pawRect.midX, y: pawRect.maxY - pawHeight * 0.1))
            context.stroke(toes, with: .color(t.accentColor.opacity(0.4)),
                           style: StrokeStyle(lineWidth: max(0.5, pawWidth * 0.06), lineCap: .round))
        }
    }

    private func drawTail(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        let w = canvasSize.width
        let h = canvasSize.height
        var tail = Path()
        var lineWidth = w * 0.065

        switch t.tail {
        case .curved:
            tail.move(to: CGPoint(x: w * 0.68, y: h * 0.92))
            tail.addQuadCurve(to: CGPoint(x: w * 0.90, y: h * 0.70),
                              control: CGPoint(x: w * 0.95, y: h * 0.92))
        case .upright:
            tail.move(to: CGPoint(x: w * 0.68, y: h * 0.94))
            tail.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.62),
                              control: CGPoint(x: w * 0.88, y: h * 0.82))
        case .curled:
            tail.move(to: CGPoint(x: w * 0.68, y: h * 0.94))
            tail.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.74),
                          control1: CGPoint(x: w * 0.96, y: h * 0.94),
                          control2: CGPoint(x: w * 0.96, y: h * 0.70))
        case .bushy:
            lineWidth = w * 0.105
            tail.move(to: CGPoint(x: w * 0.68, y: h * 0.92))
            tail.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.76),
                              control: CGPoint(x: w * 0.90, y: h * 0.92))
        }

        context.stroke(tail, with: .color(t.bodyColor),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        if t.tail == .bushy || t.tail == .upright {
            let tip = lineWidth * 0.55
            let end = t.tail == .bushy
                ? CGPoint(x: w * 0.86, y: h * 0.76)
                : CGPoint(x: w * 0.84, y: h * 0.62)
            context.fill(
                Path(ellipseIn: CGRect(x: end.x - tip, y: end.y - tip, width: tip * 2, height: tip * 2)),
                with: .color(t.accentColor.opacity(0.8))
            )
        }
    }

    private func drawEars(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        let earWidth = head.width * 0.30
        let baseY = head.minY + head.height * 0.20
        let earHeight: CGFloat = {
            switch t.ears {
            case .round: return head.height * 0.24
            case .folded: return head.height * 0.16
            default: return head.height * 0.32
            }
        }()

        for side in [-1.0, 1.0] {
            let centerX = head.midX + CGFloat(side) * head.width * 0.30
            let tipY = baseY - earHeight
            var path = Path()

            switch t.ears {
            case .pointed, .tufted:
                // Slightly bowed sides so the ear reads soft rather than spiky.
                path.move(to: CGPoint(x: centerX - earWidth / 2, y: baseY))
                path.addQuadCurve(to: CGPoint(x: centerX + CGFloat(side) * earWidth * 0.12, y: tipY),
                                  control: CGPoint(x: centerX - earWidth * 0.28, y: tipY + earHeight * 0.30))
                path.addQuadCurve(to: CGPoint(x: centerX + earWidth / 2, y: baseY),
                                  control: CGPoint(x: centerX + earWidth * 0.42, y: tipY + earHeight * 0.25))
                path.closeSubpath()
            case .round:
                path.addEllipse(in: CGRect(x: centerX - earWidth / 2, y: tipY,
                                           width: earWidth, height: earHeight * 1.5))
            case .folded:
                path.move(to: CGPoint(x: centerX - earWidth / 2, y: baseY))
                path.addQuadCurve(to: CGPoint(x: centerX - CGFloat(side) * earWidth * 0.08, y: tipY),
                                  control: CGPoint(x: centerX - earWidth * 0.3, y: tipY + earHeight * 0.2))
                path.addQuadCurve(to: CGPoint(x: centerX + earWidth / 2, y: baseY - earHeight * 0.12),
                                  control: CGPoint(x: centerX + earWidth * 0.40, y: tipY))
                path.closeSubpath()
            case .curled:
                path.move(to: CGPoint(x: centerX - earWidth / 2, y: baseY))
                path.addQuadCurve(to: CGPoint(x: centerX + CGFloat(side) * earWidth * 0.62, y: tipY),
                                  control: CGPoint(x: centerX + CGFloat(side) * earWidth * 0.05, y: tipY - earHeight * 0.15))
                path.addLine(to: CGPoint(x: centerX + earWidth / 2, y: baseY))
                path.closeSubpath()
            }
            context.fill(path, with: .color(t.bodyColor))

            if t.ears != .folded {
                let innerWidth = earWidth * 0.44
                let innerHeight = earHeight * 0.5
                var inner = Path()
                let innerBase = baseY - earHeight * 0.10
                inner.move(to: CGPoint(x: centerX - innerWidth / 2, y: innerBase))
                inner.addQuadCurve(to: CGPoint(x: centerX + CGFloat(side) * innerWidth * 0.12, y: innerBase - innerHeight),
                                   control: CGPoint(x: centerX - innerWidth * 0.2, y: innerBase - innerHeight * 0.6))
                inner.addQuadCurve(to: CGPoint(x: centerX + innerWidth / 2, y: innerBase),
                                   control: CGPoint(x: centerX + innerWidth * 0.35, y: innerBase - innerHeight * 0.5))
                inner.closeSubpath()
                context.fill(inner, with: .color(Color(red: 1.0, green: 0.72, blue: 0.76).opacity(0.6)))
            }

            if t.ears == .tufted {
                var tuft = Path()
                tuft.move(to: CGPoint(x: centerX, y: tipY + 1))
                tuft.addLine(to: CGPoint(x: centerX + CGFloat(side) * earWidth * 0.24, y: tipY - earHeight * 0.24))
                context.stroke(tuft, with: .color(t.accentColor),
                               style: StrokeStyle(lineWidth: max(1, head.width * 0.02), lineCap: .round))
            }
        }
    }

    // MARK: - Coat patterns

    private func drawPattern(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        switch t.pattern {
        case .plain:
            break

        case .tabby:
            for i in 0..<3 {
                var stripe = Path()
                let y = head.minY + head.height * (0.13 + CGFloat(i) * 0.06)
                let width = head.width * (0.14 - CGFloat(i) * 0.02)
                stripe.move(to: CGPoint(x: head.midX - width, y: y))
                stripe.addQuadCurve(to: CGPoint(x: head.midX + width, y: y),
                                    control: CGPoint(x: head.midX, y: y - head.height * 0.045))
                context.stroke(stripe, with: .color(t.accentColor.opacity(0.75)),
                               style: StrokeStyle(lineWidth: max(1.2, head.width * 0.03), lineCap: .round))
            }

        case .spotted:
            var generator = SeededGenerator(seed: PawpetTraits.daySeed(summary.day) &+ 7)
            for _ in 0..<4 {
                let dx = CGFloat(generator.nextDouble(in: -0.30...0.30))
                let dy = CGFloat(generator.nextDouble(in: -0.30...(-0.02)))   // upper face, clear of the eyes
                let radius = head.width * CGFloat(generator.nextDouble(in: 0.03...0.055))
                context.fill(
                    Path(ellipseIn: CGRect(x: head.midX + dx * head.width - radius,
                                           y: head.midY + dy * head.height - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(t.accentColor.opacity(0.45))
                )
            }

        case .tuxedo:
            var patch = context
            patch.clip(to: Path(roundedRect: head, cornerRadius: head.height * 0.48))
            patch.fill(
                Path(ellipseIn: CGRect(x: head.midX - head.width * 0.30,
                                       y: head.midY + head.height * 0.16,
                                       width: head.width * 0.60, height: head.height * 0.50)),
                with: .color(.white.opacity(0.55))
            )

        case .calico:
            var calico = context
            calico.clip(to: Path(roundedRect: head, cornerRadius: head.height * 0.48))
            calico.fill(
                Path(ellipseIn: CGRect(x: head.minX - head.width * 0.06, y: head.minY - head.height * 0.06,
                                       width: head.width * 0.42, height: head.height * 0.44)),
                with: .color(t.accentColor.opacity(0.6))
            )
            calico.fill(
                Path(ellipseIn: CGRect(x: head.maxX - head.width * 0.34, y: head.minY - head.height * 0.02,
                                       width: head.width * 0.40, height: head.height * 0.40)),
                with: .color(.white.opacity(0.5))
            )

        case .colorpoint:
            // Darker crown mask, kept up and away from the eye region.
            var point = context
            point.clip(to: Path(roundedRect: head, cornerRadius: head.height * 0.48))
            point.fill(
                Path(ellipseIn: CGRect(x: head.midX - head.width * 0.40,
                                       y: head.minY - head.height * 0.28,
                                       width: head.width * 0.80, height: head.height * 0.52)),
                with: .color(t.accentColor.opacity(0.45))
            )

        case .bicolor:
            var half = context
            half.clip(to: Path(roundedRect: head, cornerRadius: head.height * 0.48))
            // Diagonal sweep instead of a hard vertical split down the face.
            var sweep = Path()
            sweep.move(to: CGPoint(x: head.minX, y: head.minY))
            sweep.addLine(to: CGPoint(x: head.midX + head.width * 0.05, y: head.minY))
            sweep.addQuadCurve(to: CGPoint(x: head.minX + head.width * 0.18, y: head.maxY),
                               control: CGPoint(x: head.midX - head.width * 0.18, y: head.midY))
            sweep.addLine(to: CGPoint(x: head.minX, y: head.maxY))
            sweep.closeSubpath()
            half.fill(sweep, with: .color(t.accentColor.opacity(0.45)))

        case .star:
            drawSparkleStar(&context,
                            center: CGPoint(x: head.midX, y: head.minY + head.height * 0.17),
                            radius: head.width * 0.085,
                            color: .white.opacity(0.75))
        }
    }

    // MARK: - Face

    /// One eye, kawaii-style: colored iris, big glossy pupil, two glints. Everything else is a
    /// variation on this so the face stays consistent between moods.
    private func drawCuteEye(
        _ context: inout GraphicsContext,
        center: CGPoint,
        eyeSize: CGFloat,
        iris: Color,
        pupilScale: CGFloat = 0.74
    ) {
        let s = eyeSize
        let irisRect = CGRect(x: center.x - s / 2, y: center.y - s / 2, width: s, height: s)
        context.fill(Path(ellipseIn: irisRect), with: .color(iris))

        let p = s * pupilScale
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - p / 2, y: center.y - p / 2 + s * 0.03, width: p, height: p)),
            with: .color(Color(white: 0.08))
        )

        // Two glints — a big one top-left, a pinprick bottom-right. This is most of "cute".
        let bigGlint = s * 0.34
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - s * 0.26, y: center.y - s * 0.30,
                                   width: bigGlint, height: bigGlint)),
            with: .color(.white.opacity(0.95))
        )
        let smallGlint = s * 0.14
        context.fill(
            Path(ellipseIn: CGRect(x: center.x + s * 0.16, y: center.y + s * 0.12,
                                   width: smallGlint, height: smallGlint)),
            with: .color(.white.opacity(0.8))
        )
    }

    private func drawEyes(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        // Sunglasses own the region completely — see the file comment.
        guard t.eyewear != .sunglasses else { return }

        let eyeY = head.midY - head.height * 0.02
        let spacing = head.width * 0.20
        let eyeSize = head.width * 0.17
        let lineWidth = max(1.4, eyeSize * 0.16)

        for side in [-1.0, 1.0] {
            let center = CGPoint(x: head.midX + CGFloat(side) * spacing, y: eyeY)
            let rect = CGRect(x: center.x - eyeSize / 2, y: center.y - eyeSize / 2,
                              width: eyeSize, height: eyeSize)

            switch t.expression {
            case .sleepy, .zen:
                // Closed, content: a downward-bowing lid with a tiny lash.
                var lid = Path()
                lid.move(to: CGPoint(x: rect.minX, y: center.y))
                lid.addQuadCurve(to: CGPoint(x: rect.maxX, y: center.y),
                                 control: CGPoint(x: center.x, y: center.y + eyeSize * 0.55))
                context.stroke(lid, with: .color(.black.opacity(0.7)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                var lash = Path()
                lash.move(to: CGPoint(x: center.x + CGFloat(side) * eyeSize * 0.5, y: center.y + eyeSize * 0.05))
                lash.addLine(to: CGPoint(x: center.x + CGFloat(side) * eyeSize * 0.68, y: center.y + eyeSize * 0.22))
                context.stroke(lash, with: .color(.black.opacity(0.55)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))

            case .dizzy, .chaotic:
                // Symmetric @-swirls. The old chaotic design gave each eye a different pupil,
                // which looked broken rather than frazzled.
                context.stroke(spiralPath(center: center, radius: eyeSize * 0.48),
                               with: .color(.black.opacity(0.72)),
                               style: StrokeStyle(lineWidth: max(1, eyeSize * 0.13), lineCap: .round))
                if t.expression == .chaotic {
                    // Worried brows, mirrored so both sides slant the same way.
                    var brow = Path()
                    brow.move(to: CGPoint(x: center.x - CGFloat(side) * eyeSize * 0.4,
                                          y: rect.minY - eyeSize * 0.42))
                    brow.addLine(to: CGPoint(x: center.x + CGFloat(side) * eyeSize * 0.32,
                                             y: rect.minY - eyeSize * 0.22))
                    context.stroke(brow, with: .color(.black.opacity(0.5)),
                                   style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
                }

            case .focused, .determined:
                // Full cute eye with a straight upper lid: concentrating, not squinting slits.
                drawCuteEye(&context, center: center, eyeSize: eyeSize, iris: t.irisColor)
                let lidRect = CGRect(x: rect.minX - 1, y: rect.minY - 1,
                                     width: rect.width + 2, height: rect.height * 0.34)
                context.fill(Path(lidRect), with: .color(t.bodyColor))
                var lidLine = Path()
                lidLine.move(to: CGPoint(x: rect.minX, y: lidRect.maxY))
                lidLine.addLine(to: CGPoint(x: rect.maxX, y: lidRect.maxY))
                context.stroke(lidLine, with: .color(.black.opacity(0.55)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))

            case .mischief:
                // Half-lidded, both pupils drifted the same way — scheming, not broken.
                drawCuteEye(&context,
                            center: CGPoint(x: center.x + eyeSize * 0.06, y: center.y),
                            eyeSize: eyeSize, iris: t.irisColor, pupilScale: 0.62)
                let lidRect = CGRect(x: rect.minX - 1, y: rect.minY - 1,
                                     width: rect.width + 2, height: rect.height * 0.42)
                context.fill(Path(lidRect), with: .color(t.bodyColor))
                var lidLine = Path()
                lidLine.move(to: CGPoint(x: rect.minX, y: lidRect.maxY))
                lidLine.addLine(to: CGPoint(x: rect.maxX, y: lidRect.maxY))
                context.stroke(lidLine, with: .color(.black.opacity(0.5)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))

            case .tired:
                drawCuteEye(&context, center: center, eyeSize: eyeSize * 0.92,
                            iris: t.irisColor, pupilScale: 0.68)
                var bag = Path()
                bag.move(to: CGPoint(x: rect.minX + eyeSize * 0.1, y: rect.maxY + eyeSize * 0.16))
                bag.addQuadCurve(to: CGPoint(x: rect.maxX - eyeSize * 0.1, y: rect.maxY + eyeSize * 0.16),
                                 control: CGPoint(x: center.x, y: rect.maxY + eyeSize * 0.34))
                context.stroke(bag, with: .color(.black.opacity(0.25)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round))

            case .surprised:
                // White sclera ring with a smaller floating iris.
                let sclera = rect.insetBy(dx: -eyeSize * 0.12, dy: -eyeSize * 0.12)
                context.fill(Path(ellipseIn: sclera), with: .color(.white.opacity(0.95)))
                context.stroke(Path(ellipseIn: sclera), with: .color(.black.opacity(0.3)),
                               lineWidth: max(0.8, eyeSize * 0.06))
                drawCuteEye(&context, center: center, eyeSize: eyeSize * 0.62,
                            iris: t.irisColor, pupilScale: 0.7)

            case .sparkle:
                drawCuteEye(&context, center: center, eyeSize: eyeSize * 1.08,
                            iris: t.irisColor, pupilScale: 0.78)
                drawSparkleStar(&context,
                                center: CGPoint(x: center.x - eyeSize * 0.12, y: center.y - eyeSize * 0.12),
                                radius: eyeSize * 0.30, color: .white)

            case .wide:
                drawCuteEye(&context, center: center, eyeSize: eyeSize * 1.14, iris: t.irisColor)

            case .content:
                drawCuteEye(&context, center: center, eyeSize: eyeSize, iris: t.irisColor)
            }
        }
    }

    /// Inward Archimedean spiral, approximated with line segments.
    private func spiralPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let turns: CGFloat = 2.2
        let steps = 44
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        for i in 1...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let angle = progress * turns * 2 * .pi
            let r = radius * (1 - progress * 0.85)
            path.addLine(to: CGPoint(x: center.x + cos(angle) * r,
                                     y: center.y + sin(angle) * r))
        }
        return path
    }

    private func drawNoseAndMouth(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        let noseY = head.midY + head.height * 0.155
        let noseWidth = head.width * 0.07

        // Rounded nose triangle.
        var nose = Path()
        nose.move(to: CGPoint(x: head.midX - noseWidth / 2, y: noseY))
        nose.addQuadCurve(to: CGPoint(x: head.midX + noseWidth / 2, y: noseY),
                          control: CGPoint(x: head.midX, y: noseY - noseWidth * 0.35))
        nose.addQuadCurve(to: CGPoint(x: head.midX, y: noseY + noseWidth * 0.62),
                          control: CGPoint(x: head.midX + noseWidth * 0.42, y: noseY + noseWidth * 0.45))
        nose.addQuadCurve(to: CGPoint(x: head.midX - noseWidth / 2, y: noseY),
                          control: CGPoint(x: head.midX - noseWidth * 0.42, y: noseY + noseWidth * 0.45))
        context.fill(nose, with: .color(Color(red: 0.94, green: 0.55, blue: 0.60)))

        let mouthY = noseY + noseWidth * 0.85
        let mw = head.width * 0.075
        let lineWidth = max(1, head.width * 0.014)
        var mouth = Path()

        switch t.expression {
        case .surprised, .sparkle:
            context.fill(
                Path(ellipseIn: CGRect(x: head.midX - mw * 0.38, y: mouthY,
                                       width: mw * 0.76, height: mw * 0.85)),
                with: .color(.black.opacity(0.5))
            )
            return
        case .mischief:
            mouth.move(to: CGPoint(x: head.midX - mw, y: mouthY + mw * 0.1))
            mouth.addQuadCurve(to: CGPoint(x: head.midX + mw * 1.15, y: mouthY - mw * 0.15),
                               control: CGPoint(x: head.midX + mw * 0.1, y: mouthY + mw * 0.75))
        case .tired, .dizzy:
            mouth.move(to: CGPoint(x: head.midX - mw * 0.6, y: mouthY + mw * 0.25))
            mouth.addQuadCurve(to: CGPoint(x: head.midX + mw * 0.6, y: mouthY + mw * 0.25),
                               control: CGPoint(x: head.midX, y: mouthY))
        case .chaotic:
            mouth.move(to: CGPoint(x: head.midX - mw * 0.9, y: mouthY + mw * 0.2))
            mouth.addLine(to: CGPoint(x: head.midX - mw * 0.3, y: mouthY + mw * 0.55))
            mouth.addLine(to: CGPoint(x: head.midX + mw * 0.3, y: mouthY + mw * 0.2))
            mouth.addLine(to: CGPoint(x: head.midX + mw * 0.9, y: mouthY + mw * 0.55))
        default:
            // The cat "ω" — drawn shallow so it reads as a smile, not a frown.
            mouth.move(to: CGPoint(x: head.midX, y: mouthY))
            mouth.addQuadCurve(to: CGPoint(x: head.midX - mw, y: mouthY + mw * 0.1),
                               control: CGPoint(x: head.midX - mw * 0.5, y: mouthY + mw * 0.55))
            mouth.move(to: CGPoint(x: head.midX, y: mouthY))
            mouth.addQuadCurve(to: CGPoint(x: head.midX + mw, y: mouthY + mw * 0.1),
                               control: CGPoint(x: head.midX + mw * 0.5, y: mouthY + mw * 0.55))
        }
        context.stroke(mouth, with: .color(.black.opacity(0.55)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    private func drawCheekMark(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        // A soft default blush is always on — it's load-bearing for the plush look. State marks
        // layer on top of it.
        let blushSize = head.width * 0.13
        let blushY = head.midY + head.height * 0.13
        let strength: Double
        let color: Color
        switch t.cheekMark {
        case .flushed: strength = 0.5; color = Color(red: 0.95, green: 0.35, blue: 0.30)
        case .blush: strength = 0.38; color = Color(red: 0.98, green: 0.55, blue: 0.62)
        default: strength = 0.20; color = Color(red: 0.98, green: 0.55, blue: 0.62)
        }
        for side in [-1.0, 1.0] {
            context.fill(
                Path(ellipseIn: CGRect(x: head.midX + CGFloat(side) * head.width * 0.32 - blushSize / 2,
                                       y: blushY,
                                       width: blushSize, height: blushSize * 0.55)),
                with: .color(color.opacity(strength))
            )
        }

        if t.cheekMark == .sweat {
            let dropWidth = head.width * 0.09
            let x = head.maxX - dropWidth * 0.4
            let y = head.minY + head.height * 0.24
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addQuadCurve(to: CGPoint(x: x + dropWidth * 0.45, y: y + dropWidth * 1.0),
                              control: CGPoint(x: x + dropWidth * 0.5, y: y + dropWidth * 0.4))
            drop.addQuadCurve(to: CGPoint(x: x, y: y),
                              control: CGPoint(x: x - dropWidth * 0.5, y: y + dropWidth * 0.4))
            context.fill(drop, with: .color(Color(red: 0.45, green: 0.75, blue: 0.98).opacity(0.85)))
        }
    }

    private func drawWhiskers(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        // Short, faint, starting outside the muzzle — long dark whiskers crossing the face were
        // the single biggest reason the first version read as an insect.
        let baseY = head.midY + head.height * 0.17
        let length = head.width * 0.19
        let lineWidth = max(0.6, head.width * 0.009)

        for side in [-1.0, 1.0] {
            for i in 0..<min(t.whiskers, 3) {
                let offset = CGFloat(i) * head.height * 0.05 - head.height * 0.02
                var path = Path()
                let startX = head.midX + CGFloat(side) * head.width * 0.30
                path.move(to: CGPoint(x: startX, y: baseY + offset))
                path.addQuadCurve(
                    to: CGPoint(x: startX + CGFloat(side) * length,
                                y: baseY + offset + CGFloat(i - 1) * head.height * 0.035),
                    control: CGPoint(x: startX + CGFloat(side) * length * 0.55, y: baseY + offset - head.height * 0.012)
                )
                context.stroke(path, with: .color(.black.opacity(0.22)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }

    // MARK: - Worn items

    private func drawCollar(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        guard t.collar != .none else { return }
        let w = canvasSize.width
        let h = canvasSize.height
        let bandWidth = w * 0.32
        let bandHeight = h * 0.042
        let rect = CGRect(x: (w - bandWidth) / 2, y: h * 0.745, width: bandWidth, height: bandHeight)

        let color: Color = {
            switch t.collar {
            case .cloth: return Color(red: 0.80, green: 0.72, blue: 0.62)
            case .blue: return Color(red: 0.32, green: 0.58, blue: 0.92)
            case .green: return Color(red: 0.28, green: 0.74, blue: 0.48)
            case .gold: return Color(red: 0.98, green: 0.80, blue: 0.26)
            case .rainbow, .none: return .clear
            }
        }()

        if t.collar == .rainbow {
            context.fill(
                Path(roundedRect: rect, cornerRadius: bandHeight / 2),
                with: .linearGradient(
                    Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                )
            )
        } else {
            context.fill(Path(roundedRect: rect, cornerRadius: bandHeight / 2), with: .color(color))
        }

        let bell = w * 0.05
        let bellRect = CGRect(x: rect.midX - bell / 2, y: rect.maxY - bell * 0.2, width: bell, height: bell)
        context.fill(Path(ellipseIn: bellRect), with: .color(Color(red: 1.0, green: 0.84, blue: 0.32)))
        context.fill(
            Path(ellipseIn: CGRect(x: bellRect.midX - bell * 0.1, y: bellRect.minY + bell * 0.2,
                                   width: bell * 0.2, height: bell * 0.2)),
            with: .color(.white.opacity(0.7))
        )
    }

    private func drawEyewear(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        let eyeY = head.midY - head.height * 0.02
        let spacing = head.width * 0.20
        let stroke = max(1.2, head.width * 0.02)
        let rimColor = Color(red: 0.45, green: 0.32, blue: 0.22).opacity(0.85)

        switch t.eyewear {
        case .none:
            return

        case .readingGlasses:
            // Thin rims around the (visible) eyes.
            let lens = head.width * 0.24
            for side in [-1.0, 1.0] {
                let cx = head.midX + CGFloat(side) * spacing
                context.stroke(
                    Path(ellipseIn: CGRect(x: cx - lens / 2, y: eyeY - lens / 2, width: lens, height: lens)),
                    with: .color(rimColor),
                    lineWidth: stroke
                )
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: head.midX - spacing + head.width * 0.12, y: eyeY - head.height * 0.02))
            bridge.addQuadCurve(to: CGPoint(x: head.midX + spacing - head.width * 0.12, y: eyeY - head.height * 0.02),
                                control: CGPoint(x: head.midX, y: eyeY - head.height * 0.06))
            context.stroke(bridge, with: .color(rimColor), lineWidth: stroke)

        case .sunglasses:
            // Full lenses with a glare line; the eye pass drew nothing underneath.
            let lensWidth = head.width * 0.26
            let lensHeight = lensWidth * 0.80
            for side in [-1.0, 1.0] {
                let cx = head.midX + CGFloat(side) * spacing
                let rect = CGRect(x: cx - lensWidth / 2, y: eyeY - lensHeight / 2,
                                  width: lensWidth, height: lensHeight)
                context.fill(Path(roundedRect: rect, cornerRadius: lensHeight * 0.4),
                             with: .linearGradient(
                                Gradient(colors: [Color(white: 0.25), Color(white: 0.05)]),
                                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                var glare = Path()
                glare.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.7))
                glare.addLine(to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.18))
                context.stroke(glare, with: .color(.white.opacity(0.5)),
                               style: StrokeStyle(lineWidth: max(1, lensWidth * 0.08), lineCap: .round))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: head.midX - spacing + lensWidth * 0.5, y: eyeY - lensHeight * 0.18))
            bridge.addQuadCurve(to: CGPoint(x: head.midX + spacing - lensWidth * 0.5, y: eyeY - lensHeight * 0.18),
                                control: CGPoint(x: head.midX, y: eyeY - lensHeight * 0.42))
            context.stroke(bridge, with: .color(.black.opacity(0.8)), lineWidth: max(1.2, head.width * 0.022))
        }
    }

    private func drawHeadwear(_ context: inout GraphicsContext, _ head: CGRect, _ t: PawpetTraits) {
        let topY = head.minY + head.height * 0.02

        switch t.headwear {
        case .none:
            break

        case .crown:
            var crown = Path()
            let width = head.width * 0.38
            let height = head.height * 0.15
            let left = head.midX - width / 2
            crown.move(to: CGPoint(x: left, y: topY))
            crown.addLine(to: CGPoint(x: left, y: topY - height))
            crown.addLine(to: CGPoint(x: left + width * 0.25, y: topY - height * 0.45))
            crown.addLine(to: CGPoint(x: left + width * 0.5, y: topY - height * 1.15))
            crown.addLine(to: CGPoint(x: left + width * 0.75, y: topY - height * 0.45))
            crown.addLine(to: CGPoint(x: left + width, y: topY - height))
            crown.addLine(to: CGPoint(x: left + width, y: topY))
            crown.closeSubpath()
            context.fill(crown, with: .color(Color(red: 1.0, green: 0.82, blue: 0.25)))
            let gem = width * 0.09
            for fx in [0.25, 0.5, 0.75] {
                context.fill(
                    Path(ellipseIn: CGRect(x: left + width * fx - gem / 2, y: topY - height * 0.32,
                                           width: gem, height: gem)),
                    with: .color(Color(red: 0.90, green: 0.30, blue: 0.40))
                )
            }

        case .partyHat:
            var hat = Path()
            let width = head.width * 0.28
            let apexY = head.minY - head.height * 0.24
            hat.move(to: CGPoint(x: head.midX - width / 2, y: topY + head.height * 0.02))
            hat.addLine(to: CGPoint(x: head.midX, y: apexY))
            hat.addLine(to: CGPoint(x: head.midX + width / 2, y: topY + head.height * 0.02))
            hat.closeSubpath()
            context.fill(hat, with: .linearGradient(
                Gradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.55),
                                  Color(red: 0.85, green: 0.30, blue: 0.60)]),
                startPoint: CGPoint(x: head.midX, y: apexY),
                endPoint: CGPoint(x: head.midX, y: topY)))
            let pom = head.width * 0.08
            context.fill(
                Path(ellipseIn: CGRect(x: head.midX - pom / 2, y: apexY - pom * 0.7, width: pom, height: pom)),
                with: .color(.yellow)
            )

        case .halo:
            let ringWidth = head.width * 0.44
            let ringHeight = head.height * 0.10
            context.stroke(
                Path(ellipseIn: CGRect(x: head.midX - ringWidth / 2, y: head.minY - head.height * 0.24,
                                       width: ringWidth, height: ringHeight)),
                with: .color(Color(red: 1.0, green: 0.90, blue: 0.42)),
                lineWidth: max(1.5, head.width * 0.032)
            )

        case .headphones:
            var band = Path()
            band.addArc(center: CGPoint(x: head.midX, y: head.minY + head.height * 0.30),
                        radius: head.width * 0.38,
                        startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(band, with: .color(t.accentColor),
                           style: StrokeStyle(lineWidth: max(2, head.width * 0.045), lineCap: .round))
            for side in [-1.0, 1.0] {
                let cupWidth = head.width * 0.14
                context.fill(
                    Path(roundedRect: CGRect(x: head.midX + CGFloat(side) * head.width * 0.38 - cupWidth / 2,
                                             y: head.minY + head.height * 0.24,
                                             width: cupWidth, height: cupWidth * 1.3),
                         cornerRadius: cupWidth * 0.4),
                    with: .color(t.accentColor)
                )
            }

        case .nightcap:
            var cap = Path()
            let width = head.width * 0.50
            let left = head.midX - width / 2
            cap.move(to: CGPoint(x: left, y: topY + head.height * 0.05))
            cap.addQuadCurve(to: CGPoint(x: left + width, y: topY + head.height * 0.05),
                             control: CGPoint(x: head.midX + width * 0.1, y: head.minY - head.height * 0.30))
            cap.closeSubpath()
            context.fill(cap, with: .color(Color(red: 0.42, green: 0.46, blue: 0.80)))
            let pom = head.width * 0.09
            context.fill(
                Path(ellipseIn: CGRect(x: head.midX + width * 0.28, y: head.minY - head.height * 0.22,
                                       width: pom, height: pom)),
                with: .color(.white.opacity(0.9))
            )

        case .beanie:
            let width = head.width * 0.68
            let height = head.height * 0.24
            let rect = CGRect(x: head.midX - width / 2, y: head.minY - height * 0.5,
                              width: width, height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: height * 0.5),
                         with: .color(Color(red: 0.86, green: 0.42, blue: 0.36)))
            context.fill(
                Path(roundedRect: CGRect(x: rect.minX, y: rect.maxY - height * 0.30,
                                         width: width, height: height * 0.34),
                     cornerRadius: height * 0.16),
                with: .color(Color(red: 0.96, green: 0.62, blue: 0.52))
            )

        case .bandana:
            var scarf = Path()
            let width = head.width * 0.62
            let left = head.midX - width / 2
            scarf.move(to: CGPoint(x: left, y: topY + head.height * 0.08))
            scarf.addQuadCurve(to: CGPoint(x: left + width, y: topY + head.height * 0.08),
                               control: CGPoint(x: head.midX, y: head.minY - head.height * 0.12))
            scarf.addLine(to: CGPoint(x: left + width, y: topY + head.height * 0.17))
            scarf.addQuadCurve(to: CGPoint(x: left, y: topY + head.height * 0.17),
                               control: CGPoint(x: head.midX, y: head.minY - head.height * 0.01))
            scarf.closeSubpath()
            context.fill(scarf, with: .color(Color(red: 0.90, green: 0.32, blue: 0.38)))
        }
    }

    // MARK: - Rewards

    private func drawBackdrop(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        let w = canvasSize.width
        let h = canvasSize.height
        let center = CGPoint(x: w / 2, y: h * 0.48)

        switch t.backdrop {
        case .none:
            break

        case .rays:
            for i in 0..<12 {
                let angle = CGFloat(i) * .pi / 6
                let inner = w * 0.20
                let outer = w * 0.50
                let spread: CGFloat = 0.055
                var ray = Path()
                ray.move(to: CGPoint(x: center.x + cos(angle - spread) * inner,
                                     y: center.y + sin(angle - spread) * inner))
                ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer,
                                        y: center.y + sin(angle) * outer))
                ray.addLine(to: CGPoint(x: center.x + cos(angle + spread) * inner,
                                        y: center.y + sin(angle + spread) * inner))
                ray.closeSubpath()
                context.fill(ray, with: .color(Color(red: 1.0, green: 0.86, blue: 0.42)
                    .opacity(i.isMultiple(of: 2) ? 0.26 : 0.14)))
            }

        case .orbit:
            for i in 0..<2 {
                let radius = w * (0.34 + CGFloat(i) * 0.07)
                var ring = Path()
                ring.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 0.42,
                                           width: radius * 2, height: radius * 0.84))
                context.stroke(ring, with: .color(Color.cyan.opacity(0.30)),
                               lineWidth: max(1, w * 0.008))
                let dot = w * 0.022
                let angle = CGFloat(i) * 2.1 + 0.6
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x + cos(angle) * radius - dot,
                                           y: center.y + sin(angle) * radius * 0.42 - dot,
                                           width: dot * 2, height: dot * 2)),
                    with: .color(Color.cyan.opacity(0.7))
                )
            }

        case .constellation:
            var generator = SeededGenerator(seed: PawpetTraits.daySeed(summary.day) &+ 991)
            var previous: CGPoint?
            for _ in 0..<7 {
                let point = CGPoint(x: w * CGFloat(generator.nextDouble(in: 0.10...0.90)),
                                    y: h * CGFloat(generator.nextDouble(in: 0.06...0.50)))
                let size = w * CGFloat(generator.nextDouble(in: 0.010...0.022))
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - size, y: point.y - size,
                                           width: size * 2, height: size * 2)),
                    with: .color(.white.opacity(0.85))
                )
                if let previous {
                    var link = Path()
                    link.move(to: previous)
                    link.addLine(to: point)
                    context.stroke(link, with: .color(.white.opacity(0.25)), lineWidth: max(0.5, w * 0.004))
                }
                previous = point
            }
        }
    }

    private func drawWings(
        _ context: inout GraphicsContext,
        _ canvasSize: CGSize,
        _ head: CGRect,
        _ t: PawpetTraits
    ) {
        guard t.wings != .none else { return }
        let w = canvasSize.width
        let h = canvasSize.height
        let anchorY = h * 0.74
        let color: Color
        switch t.wings {
        case .feathered: color = Color(red: 0.96, green: 0.97, blue: 1.0)
        case .crystal: color = Color(red: 0.62, green: 0.88, blue: 0.98)
        case .ember: color = Color(red: 1.0, green: 0.60, blue: 0.32)
        case .none: return
        }

        for side in [-1.0, 1.0] {
            let direction = CGFloat(side)
            // Kept inside the frame: at the old reach the outermost feather ended past the
            // canvas edge, so in a grid the wings hung over the gaps like stickers.
            let root = CGPoint(x: w * 0.5 + direction * w * 0.15, y: anchorY)
            for i in 0..<3 {
                let reach = w * (0.17 + CGFloat(i) * 0.035)
                let lift = h * (0.09 + CGFloat(i) * 0.06)
                var feather = Path()
                feather.move(to: root)
                feather.addQuadCurve(
                    to: CGPoint(x: root.x + direction * reach, y: root.y - lift),
                    control: CGPoint(x: root.x + direction * reach * 0.35, y: root.y - lift * 1.25)
                )
                feather.addQuadCurve(
                    to: root,
                    control: CGPoint(x: root.x + direction * reach * 0.72, y: root.y - lift * 0.15)
                )
                feather.closeSubpath()
                context.fill(feather, with: .color(color.opacity(0.28 + Double(i) * 0.12)))
                context.stroke(feather, with: .color(color.opacity(0.5)), lineWidth: max(0.5, w * 0.004))
            }
        }
    }

    private func drawPawCharm(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        guard t.pawCharm != .none else { return }
        let w = canvasSize.width
        let h = canvasSize.height
        let center = CGPoint(x: w * 0.76, y: h * 0.85)
        let radius = w * 0.10

        let tint: Color
        switch t.pawCharm {
        case .orb: tint = Color(red: 0.45, green: 0.80, blue: 1.0)
        case .gauntlet: tint = Color(red: 1.0, green: 0.78, blue: 0.30)
        case .star: tint = Color(red: 1.0, green: 0.92, blue: 0.45)
        case .ring: tint = Color(red: 0.80, green: 0.60, blue: 1.0)
        case .flame: tint = Color(red: 1.0, green: 0.52, blue: 0.24)
        case .crystal: tint = Color(red: 0.55, green: 0.95, blue: 0.85)
        case .feather: tint = Color(red: 0.98, green: 0.98, blue: 1.0)
        case .none: return
        }

        // Soft radial glow, then the object.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 2.0, y: center.y - radius * 2.0,
                                   width: radius * 4.0, height: radius * 4.0)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(0.35), tint.opacity(0.0)]),
                center: center, startRadius: 0, endRadius: radius * 2.0)
        )

        switch t.pawCharm {
        case .orb:
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [.white, tint]),
                                               center: CGPoint(x: center.x - radius * 0.3,
                                                               y: center.y - radius * 0.3),
                                               startRadius: 0, endRadius: radius * 1.4))

        case .gauntlet:
            let box = CGRect(x: center.x - radius, y: center.y - radius * 0.85,
                             width: radius * 2, height: radius * 1.7)
            context.fill(Path(roundedRect: box, cornerRadius: radius * 0.35), with: .color(tint))
            context.fill(Path(roundedRect: box.insetBy(dx: radius * 0.42, dy: radius * 0.55),
                              cornerRadius: radius * 0.2),
                         with: .color(.white.opacity(0.85)))

        case .star:
            drawSparkleStar(&context, center: center, radius: radius * 1.25, color: tint)
            drawSparkleStar(&context, center: center, radius: radius * 0.7, color: .white)

        case .ring:
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                  width: radius * 2, height: radius * 2)),
                           with: .color(tint), lineWidth: radius * 0.42)
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                  width: radius * 2, height: radius * 2)),
                           with: .color(.white.opacity(0.7)), lineWidth: radius * 0.14)

        case .flame:
            var flame = Path()
            flame.move(to: CGPoint(x: center.x, y: center.y - radius * 1.5))
            flame.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.5),
                               control: CGPoint(x: center.x + radius * 1.1, y: center.y - radius * 0.5))
            flame.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.5),
                               control: CGPoint(x: center.x, y: center.y + radius * 1.3))
            flame.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius * 1.5),
                               control: CGPoint(x: center.x - radius * 1.1, y: center.y - radius * 0.5))
            context.fill(flame, with: .color(tint))
            var inner = Path()
            inner.move(to: CGPoint(x: center.x, y: center.y - radius * 0.75))
            inner.addQuadCurve(to: CGPoint(x: center.x + radius * 0.45, y: center.y + radius * 0.45),
                               control: CGPoint(x: center.x + radius * 0.55, y: center.y))
            inner.addQuadCurve(to: CGPoint(x: center.x - radius * 0.45, y: center.y + radius * 0.45),
                               control: CGPoint(x: center.x, y: center.y + radius * 0.85))
            inner.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius * 0.75),
                               control: CGPoint(x: center.x - radius * 0.55, y: center.y))
            context.fill(inner, with: .color(.white.opacity(0.75)))

        case .crystal:
            var gem = Path()
            gem.move(to: CGPoint(x: center.x, y: center.y - radius * 1.4))
            gem.addLine(to: CGPoint(x: center.x + radius * 0.85, y: center.y - radius * 0.2))
            gem.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.4))
            gem.addLine(to: CGPoint(x: center.x - radius * 0.85, y: center.y - radius * 0.2))
            gem.closeSubpath()
            context.fill(gem, with: .color(tint))
            var facet = Path()
            facet.move(to: CGPoint(x: center.x, y: center.y - radius * 1.4))
            facet.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.4))
            context.stroke(facet, with: .color(.white.opacity(0.75)), lineWidth: max(1, radius * 0.14))

        case .feather:
            var quill = Path()
            quill.move(to: CGPoint(x: center.x - radius * 0.5, y: center.y + radius * 1.2))
            quill.addQuadCurve(to: CGPoint(x: center.x + radius * 0.6, y: center.y - radius * 1.2),
                               control: CGPoint(x: center.x + radius * 1.1, y: center.y))
            quill.addQuadCurve(to: CGPoint(x: center.x - radius * 0.5, y: center.y + radius * 1.2),
                               control: CGPoint(x: center.x - radius * 0.5, y: center.y - radius * 0.2))
            quill.closeSubpath()
            context.fill(quill, with: .color(tint))

        case .none:
            break
        }
    }

    /// Border earned by the day's grade — drawn as an actual picture frame, not a colored line:
    /// gradient "metal" outer band, lighter inner hairline, and corner ornaments per tier.
    private func drawFrame(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        guard t.frame != .none else { return }
        let w = canvasSize.width
        let lineWidth = w * 0.030
        // Inset by a full line width so the stroke lives entirely inside the canvas; half of it
        // used to be clipped off at the edge, which is why the old frames looked like flat bands.
        let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: lineWidth, dy: lineWidth)
        let corner = w * 0.13
        let border = Path(roundedRect: rect, cornerRadius: corner)
        let hairline = Path(roundedRect: rect.insetBy(dx: lineWidth * 0.85, dy: lineWidth * 0.85),
                            cornerRadius: corner * 0.82)

        func metal(_ dark: Color, _ light: Color, rivet: Color) {
            context.stroke(border,
                           with: .linearGradient(
                            Gradient(stops: [
                                .init(color: light, location: 0),
                                .init(color: dark, location: 0.45),
                                .init(color: light, location: 0.75),
                                .init(color: dark, location: 1)
                            ]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: w, y: canvasSize.height)),
                           lineWidth: lineWidth)
            context.stroke(hairline, with: .color(.white.opacity(0.30)), lineWidth: lineWidth * 0.22)
            // Corner rivets sell the "physical frame" read.
            for point in cornerPoints(rect) {
                let r = lineWidth * 0.42
                context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(rivet))
            }
        }

        switch t.frame {
        case .none:
            return
        case .bronze:
            metal(Color(red: 0.52, green: 0.33, blue: 0.20),
                  Color(red: 0.85, green: 0.60, blue: 0.38),
                  rivet: Color(red: 0.95, green: 0.75, blue: 0.55))
        case .silver:
            metal(Color(red: 0.55, green: 0.58, blue: 0.65),
                  Color(red: 0.94, green: 0.96, blue: 1.0),
                  rivet: .white)
        case .gold:
            metal(Color(red: 0.78, green: 0.54, blue: 0.14),
                  Color(red: 1.0, green: 0.90, blue: 0.50),
                  rivet: Color(red: 1.0, green: 0.95, blue: 0.70))
            for point in cornerPoints(rect) {
                drawSparkleStar(&context, center: point, radius: w * 0.038,
                                color: Color(red: 1.0, green: 0.95, blue: 0.70))
            }
        case .prismatic:
            // Soft glow under the band, then a conic rainbow so the hue travels *around* the
            // frame instead of just crossing it diagonally.
            context.stroke(border, with: .color(.white.opacity(0.18)), lineWidth: lineWidth * 2.1)
            context.stroke(border,
                           with: .conicGradient(
                            Gradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]),
                            center: CGPoint(x: w / 2, y: canvasSize.height / 2),
                            angle: .degrees(0)),
                           lineWidth: lineWidth * 1.1)
            context.stroke(hairline, with: .color(.white.opacity(0.45)), lineWidth: lineWidth * 0.22)
            for point in cornerPoints(rect) {
                drawSparkleStar(&context, center: point, radius: w * 0.045, color: .white)
            }
        }
    }

    private func cornerPoints(_ rect: CGRect) -> [CGPoint] {
        let inset = rect.width * 0.11
        return [
            CGPoint(x: rect.minX + inset, y: rect.minY + inset),
            CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
            CGPoint(x: rect.minX + inset, y: rect.maxY - inset),
            CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        ]
    }

    // MARK: - Props & floaters

    private func drawProp(_ context: inout GraphicsContext, _ canvasSize: CGSize, _ t: PawpetTraits) {
        guard t.prop != .none else { return }
        let w = canvasSize.width
        let h = canvasSize.height
        let unit = w * 0.12
        let cx = w * 0.20
        let cy = h * 0.83

        switch t.prop {
        case .none:
            break

        case .coffee:
            let cup = CGRect(x: cx - unit * 0.5, y: cy - unit * 0.5, width: unit, height: unit * 1.05)
            context.fill(Path(roundedRect: cup, cornerRadius: unit * 0.18), with: .color(.white.opacity(0.92)))
            context.fill(Path(roundedRect: CGRect(x: cup.minX, y: cup.minY, width: unit, height: unit * 0.26),
                              cornerRadius: unit * 0.1),
                         with: .color(Color(red: 0.42, green: 0.26, blue: 0.16)))
            var steam = Path()
            steam.move(to: CGPoint(x: cup.midX, y: cup.minY - unit * 0.15))
            steam.addQuadCurve(to: CGPoint(x: cup.midX, y: cup.minY - unit * 0.65),
                               control: CGPoint(x: cup.midX + unit * 0.30, y: cup.minY - unit * 0.4))
            context.stroke(steam, with: .color(.white.opacity(0.7)), lineWidth: max(1, unit * 0.10))

        case .mouse:
            let body = CGRect(x: cx - unit * 0.42, y: cy - unit * 0.4, width: unit * 0.84, height: unit * 1.1)
            context.fill(Path(roundedRect: body, cornerRadius: unit * 0.42), with: .color(.white.opacity(0.9)))
            var split = Path()
            split.move(to: CGPoint(x: body.midX, y: body.minY + unit * 0.12))
            split.addLine(to: CGPoint(x: body.midX, y: body.minY + unit * 0.45))
            context.stroke(split, with: .color(.black.opacity(0.35)), lineWidth: max(0.8, unit * 0.07))

        case .plug:
            var bolt = Path()
            bolt.move(to: CGPoint(x: cx + unit * 0.10, y: cy - unit * 0.60))
            bolt.addLine(to: CGPoint(x: cx - unit * 0.30, y: cy + unit * 0.08))
            bolt.addLine(to: CGPoint(x: cx + unit * 0.02, y: cy + unit * 0.08))
            bolt.addLine(to: CGPoint(x: cx - unit * 0.10, y: cy + unit * 0.62))
            bolt.addLine(to: CGPoint(x: cx + unit * 0.34, y: cy - unit * 0.10))
            bolt.addLine(to: CGPoint(x: cx + unit * 0.02, y: cy - unit * 0.10))
            bolt.closeSubpath()
            context.fill(bolt, with: .color(Color(red: 0.98, green: 0.82, blue: 0.24)))

        case .yarn:
            let ball = CGRect(x: cx - unit * 0.55, y: cy - unit * 0.45, width: unit * 1.1, height: unit * 1.1)
            context.fill(Path(ellipseIn: ball), with: .color(Color(red: 0.92, green: 0.48, blue: 0.56)))
            for i in 0..<3 {
                var thread = Path()
                let inset = unit * (0.16 + CGFloat(i) * 0.14)
                thread.addArc(center: CGPoint(x: ball.midX, y: ball.midY), radius: ball.width / 2 - inset,
                              startAngle: .degrees(-40), endAngle: .degrees(200), clockwise: false)
                context.stroke(thread, with: .color(.white.opacity(0.55)), lineWidth: max(0.8, unit * 0.07))
            }

        case .moon:
            var moon = Path()
            let r = unit * 0.55
            moon.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                        startAngle: .degrees(50), endAngle: .degrees(310), clockwise: false)
            moon.addArc(center: CGPoint(x: cx + r * 0.55, y: cy), radius: r * 0.95,
                        startAngle: .degrees(305), endAngle: .degrees(55), clockwise: true)
            moon.closeSubpath()
            context.fill(moon, with: .color(Color(red: 1.0, green: 0.92, blue: 0.60)))

        case .book:
            let book = CGRect(x: cx - unit * 0.55, y: cy - unit * 0.35, width: unit * 1.1, height: unit * 0.8)
            context.fill(Path(roundedRect: book, cornerRadius: unit * 0.08),
                         with: .color(Color(red: 0.36, green: 0.56, blue: 0.86)))
            var spine = Path()
            spine.move(to: CGPoint(x: book.midX, y: book.minY))
            spine.addLine(to: CGPoint(x: book.midX, y: book.maxY))
            context.stroke(spine, with: .color(.white.opacity(0.75)), lineWidth: max(0.8, unit * 0.08))

        case .fish:
            var fish = Path()
            fish.move(to: CGPoint(x: cx - unit * 0.55, y: cy))
            fish.addQuadCurve(to: CGPoint(x: cx + unit * 0.30, y: cy),
                              control: CGPoint(x: cx - unit * 0.12, y: cy - unit * 0.45))
            fish.addQuadCurve(to: CGPoint(x: cx - unit * 0.55, y: cy),
                              control: CGPoint(x: cx - unit * 0.12, y: cy + unit * 0.45))
            fish.closeSubpath()
            context.fill(fish, with: .color(Color(red: 0.56, green: 0.78, blue: 0.94)))
            var tailFin = Path()
            tailFin.move(to: CGPoint(x: cx + unit * 0.28, y: cy))
            tailFin.addLine(to: CGPoint(x: cx + unit * 0.62, y: cy - unit * 0.30))
            tailFin.addLine(to: CGPoint(x: cx + unit * 0.62, y: cy + unit * 0.30))
            tailFin.closeSubpath()
            context.fill(tailFin, with: .color(Color(red: 0.40, green: 0.66, blue: 0.88)))
        }
    }

    private func drawFloaters(
        _ context: inout GraphicsContext,
        _ canvasSize: CGSize,
        _ head: CGRect,
        _ t: PawpetTraits
    ) {
        let w = canvasSize.width
        let unit = w * 0.085

        switch t.floaters {
        case .none:
            break

        case .zzz:
            for i in 0..<3 {
                let scale = 1.0 - CGFloat(i) * 0.22
                let x = head.maxX + unit * (0.1 + CGFloat(i) * 0.5)
                let y = head.minY - unit * (CGFloat(i) * 0.7) + unit * 0.3
                let s = unit * scale * 0.65
                var z = Path()
                z.move(to: CGPoint(x: x, y: y))
                z.addLine(to: CGPoint(x: x + s, y: y))
                z.addLine(to: CGPoint(x: x, y: y + s))
                z.addLine(to: CGPoint(x: x + s, y: y + s))
                context.stroke(z, with: .color(.secondary.opacity(0.65)),
                               style: StrokeStyle(lineWidth: max(0.9, s * 0.16), lineCap: .round))
            }

        case .sparkles:
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.15, 0.22, 1.0), (0.85, 0.16, 0.75), (0.80, 0.44, 0.55)]
            for (fx, fy, scale) in spots {
                drawSparkleStar(&context, center: CGPoint(x: w * fx, y: canvasSize.height * fy),
                                radius: unit * 0.55 * scale, color: Color(red: 1.0, green: 0.85, blue: 0.35))
            }

        case .notes:
            for i in 0..<2 {
                let x = head.maxX + unit * (0.25 + CGFloat(i) * 0.75)
                let y = head.minY - unit * CGFloat(i) * 0.55
                let headSize = unit * 0.38
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: headSize * 1.2, height: headSize)),
                    with: .color(.secondary.opacity(0.75))
                )
                var stem = Path()
                stem.move(to: CGPoint(x: x + headSize * 1.2, y: y + headSize * 0.5))
                stem.addLine(to: CGPoint(x: x + headSize * 1.2, y: y - headSize * 1.1))
                context.stroke(stem, with: .color(.secondary.opacity(0.75)),
                               style: StrokeStyle(lineWidth: max(0.8, headSize * 0.22), lineCap: .round))
            }

        case .bits:
            for i in 0..<4 {
                let x = head.maxX + unit * (0.2 + CGFloat(i % 2) * 0.55)
                let y = head.minY - unit * CGFloat(i) * 0.42
                let s = unit * 0.24
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: y, width: s, height: s), cornerRadius: s * 0.25),
                    with: .color(Color(red: 0.36, green: 0.76, blue: 0.86).opacity(0.8))
                )
            }
        }
    }

    /// Four-pointed sparkle, used by eyes, charms and frames.
    private func drawSparkleStar(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        var star = Path()
        let waist = radius * 0.22
        star.move(to: CGPoint(x: center.x, y: center.y - radius))
        star.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y),
                          control: CGPoint(x: center.x + waist, y: center.y - waist))
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius),
                          control: CGPoint(x: center.x + waist, y: center.y + waist))
        star.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y),
                          control: CGPoint(x: center.x - waist, y: center.y + waist))
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius),
                          control: CGPoint(x: center.x - waist, y: center.y - waist))
        star.closeSubpath()
        context.fill(star, with: .color(color))
    }
}
