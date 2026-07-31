import SwiftUI
import PawprintCore

/// The reference's palette. Deliberately not evenly spaced around the wheel — evenly spaced hues
/// are a large part of what makes a generated gradient look generated.
///
/// Outside `CatFoil` because a generic type cannot hold a static stored property.
private let foilSpectrum: [Color] = [
    Color(red: 0.788, green: 0.161, blue: 0.945),   // violet #c929f1
    Color(red: 0.051, green: 0.741, blue: 0.914),   // blue   #0dbde9
    Color(red: 0.129, green: 0.914, blue: 0.522),   // green  #21e985
    Color(red: 0.933, green: 0.874, blue: 0.063),   // yellow #eedf10
    Color(red: 0.973, green: 0.055, blue: 0.208),   // red    #f80e35
]

/// A holographic finish, following the construction `pokemon-cards-css` uses.
///
/// The previous attempt was a clean rainbow sweep, and a clean rainbow is exactly what real foil is
/// not: it read as neon cellophane. Reading the reference implementation turned up three things it
/// was missing, and each of them is doing more work than the rainbow itself.
///
/// 1. **Grain.** The rainbow is overlaid with one-point scanlines. Foil is a diffraction grating —
///    physically a field of fine ridges — and without that high-frequency break-up any gradient
///    looks printed rather than etched.
/// 2. **The filter, and its direction.** The reference *desaturates* and pushes contrast hard
///    (`contrast(2.2) saturate(0.75)` on its rarest card). Saturated hues at low contrast is the
///    look of a colour filter; muted hues at crushed contrast is the look of metal.
/// 3. **A shading pass.** A radial ramp at the pointer, `luminosity` at `contrast(4)`, driving
///    everything away from the light down towards black. Foil is dark until it catches the light;
///    lit everywhere at once is the giveaway of a static texture.
///
/// The layers are the reference's, and so are the blend modes:
///
/// | Layer | Reference | Blend |
/// |---|---|---|
/// | Rainbow × scanlines | `.card__shine` | `colorDodge` |
/// | Vertical pillars | `.card__shine:before` | `hardLight` |
/// | Shading ramp | `.card__shine:after` | `luminosity` |
/// | Specular glare | `.card__glare` | `overlay` |
///
/// The pointer is the light, and its travel is amplified — 2.6× across, 3.5× down, from the
/// reference — because a foil's colours sweep much further than the hand tilting it.
///
/// Each tier adds a layer rather than turning one up: satin gets a muted shine, holographic the
/// full rainbow, prismatic the pillars, radiant the glitter and the hardest filter.
///
/// **Cost.** At rest a card draws the shine dimly and nothing else. Everything that tracks the
/// light exists only while the pointer is inside that card, and it is inside one at a time.
struct CatFoil<Content: View, Subject: View>: View {
    let lustre: CatLustre
    /// Distinguishes two cards with the same lustre. The day string is the natural choice.
    let seed: String
    var size: CGFloat

    /// The card as it is seen.
    @ViewBuilder var content: () -> Content
    /// The same drawing with nothing behind it, used only for its alpha.
    ///
    /// **`ImageRenderer` cannot do this.** A `Canvas` used as a mask renders empty there, so the
    /// debug screenshot of the detail card shows the bars running over the cat and no artwork
    /// pattern at all. The running application is correct — the real-window captures show it — and
    /// nothing the app *ships* renders a foil through `ImageRenderer`: the share card draws the cat
    /// without one. It is a limitation of the screenshot tooling, not of the card.
    ///
    /// This is what lets the card have *regions*. A real holo does not print one texture across
    /// the whole face: the bars run over the background and stop at the artwork, which gets a
    /// pattern of its own. Without a silhouette to cut against there is only one surface, and one
    /// surface is what made this read as a shiny square rather than a card with a cat on it.
    @ViewBuilder var subject: () -> Subject

    @State private var pointer: UnitPoint?

    /// A captured window contains no pointer, so screenshots force one.
    static var forcedPointer: UnitPoint? {
        guard let raw = DebugEnvironment.foilPointer else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return UnitPoint(x: parts[0], y: parts[1])
    }

    // MARK: - Geometry

    private var cornerRadius: CGFloat { size * 0.15 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    private var light: UnitPoint { pointer ?? Self.forcedPointer ?? UnitPoint(x: 0.5, y: 0.42) }
    private var lightX: Double { Double(light.x) }
    private var lightY: Double { Double(light.y) }
    private var isLit: Bool { pointer != nil || Self.forcedPointer != nil }

    /// 0 at the centre, 1 at a corner. The reference drives brightness from this, so a card is at
    /// its most alive when the light glances off an edge.
    private var fromCentre: Double {
        min(1, (pow(lightX - 0.5, 2) + pow(lightY - 0.5, 2)).squareRoot() * 2)
    }

    /// 0–1 across the lustre scale.
    private var strength: Double { min(1, max(0, lustre.value / 100)) }

    /// Small cards get less of everything.
    ///
    /// Not vanity: the layers are built from features with a fixed size — one-point scanlines, a
    /// three-percent bar pitch — so at 62 points they are proportionally four times coarser than on
    /// the 150-point card and swamp a cat that is only 62 points of drawing to begin with. A real
    /// foil seen small shows less of itself too.
    private var scaleAttenuation: Double { min(1, max(0.45, Double(size) / 150)) }

    /// A stable per-card offset, so two cards of the same tier are never in phase.
    private var phase: Double {
        let hash = seed.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        return Double(hash % 997) / 997
    }

    // MARK: - Body

    var body: some View {
        content()
            .overlay { if lustre.finish > .matte { foil } }
            .overlay { if lustre.finish > .matte { glare } }
            .clipShape(shape)
            .overlay { if lustre.finish >= .holographic { rim } }
            .rotation3DEffect(.degrees((lightY - 0.5) * -12 * tilt),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees((lightX - 0.5) * 14 * tilt),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .animation(.easeOut(duration: 0.2), value: pointer)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    pointer = UnitPoint(x: min(1, max(0, Double(point.x) / Double(size))),
                                        y: min(1, max(0, Double(point.y) / Double(size))))
                case .ended:
                    pointer = nil
                }
            }
    }

    /// No tilt at rest — a grid of permanently skewed thumbnails looks broken, not shiny.
    private var tilt: Double { isLit ? 1 : 0 }

    @ViewBuilder private var foil: some View {
        ZStack {
            // The rainbow runs across the whole face; it is the surface, not a pattern.
            shine
            // The bars belong to the background — on a real card they run behind the artwork and
            // stop at its edge. Cutting the cat out of them is most of what makes this read as
            // printed rather than filtered.
            if lustre.finish >= .prismatic {
                // Masked *before* the blend mode, not after. A `blendMode` composites against the
                // backdrop of its containing group, and applying one inside a masked subtree makes
                // the layer escape its own mask — the bars drew over the cat and the shards drew
                // over the background, which is exactly the single-surface look this replaced.
                pillarField
                    .mask { background }
                    .compositingGroup()
                    .brightness(0.12)
                    .contrast(1.1)
                    .blendMode(.hardLight)
                    .opacity((isLit ? 0.34 : 0.12) * scaleAttenuation)
            }
            // …and the cat gets a texture of its own, which is the point of the whole exercise.
            if lustre.finish >= .holographic {
                subjectPattern
                    .mask { subject() }
                    .compositingGroup()
                    .blendMode(subjectBlend)
                    .opacity(subjectOpacity * scaleAttenuation)
            }
            if isLit { shading }
            if lustre.finish == .radiant { glitter }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }

    // MARK: - Regions

    /// Everything the cat is not.
    private var background: some View {
        Rectangle()
            .overlay { subject().blendMode(.destinationOut) }
            .compositingGroup()
    }

    /// What the artwork itself is finished in.
    ///
    /// Each tier gets a different texture rather than more of the same one, which is how the real
    /// cards are graded: a rainbow rare is not a holo turned up, it is a different print.
    @ViewBuilder private var subjectPattern: some View {
        switch lustre.finish {
        case .matte, .satin:
            EmptyView()
        case .holographic:
            // Fine crosshatch. The quietest of the three, because it is also the commonest.
            lattice(pitch: 0.085, lineWidth: 0.7, nodes: false)
        case .prismatic:
            // Cracked ice: angular shards, the way a radiant holo facets its artwork.
            crackedIce
        case .radiant:
            // A lattice with lit nodes over a starfield — the busiest print, for the rarest cat.
            ZStack {
                cosmos
                lattice(pitch: 0.06, lineWidth: 0.6, nodes: true).blendMode(.screen)
            }
            .compositingGroup()
        }
    }

    /// Crosshatch sits *under* the artwork's own colour; shards and stars sit on top of it.
    private var subjectBlend: BlendMode {
        lustre.finish == .holographic ? .softLight : .colorDodge
    }

    private var subjectOpacity: Double {
        switch lustre.finish {
        case .matte, .satin: return 0
        case .holographic:   return isLit ? 0.85 : 0.30
        case .prismatic:     return isLit ? 0.55 : 0.16
        case .radiant:       return isLit ? 0.70 : 0.22
        }
    }

    // MARK: - Subject patterns

    /// A diamond crosshatch, drifting against the light.
    ///
    /// Rotated 45° so it never lines up with the scanlines underneath it — two grids at the same
    /// angle beat into moiré, which looks like a rendering fault rather than a texture.
    private func lattice(pitch: Double, lineWidth: Double, nodes: Bool) -> some View {
        Canvas { context, canvasSize in
            let span = max(canvasSize.width, canvasSize.height) * 1.8
            let step = pitch * canvasSize.width
            guard step > 0.5 else { return }
            // The whole lattice slides a little with the pointer, so it is a surface being tilted
            // rather than a decal stuck to the cat.
            let slide = CGSize(width: (0.5 - lightX) * 0.20 * canvasSize.width,
                               height: (0.5 - lightY) * 0.20 * canvasSize.height)
            context.translateBy(x: canvasSize.width / 2 + slide.width,
                                y: canvasSize.height / 2 + slide.height)
            context.rotate(by: .degrees(45))

            var offset = -span / 2
            while offset < span / 2 {
                for path in [Path { $0.move(to: CGPoint(x: offset, y: -span / 2))
                                    $0.addLine(to: CGPoint(x: offset, y: span / 2)) },
                             Path { $0.move(to: CGPoint(x: -span / 2, y: offset))
                                    $0.addLine(to: CGPoint(x: span / 2, y: offset)) }] {
                    context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: lineWidth)
                }
                offset += step
            }

            guard nodes else { return }
            // A bright point at each crossing, brightest nearest the light. This is the sparkle a
            // rainbow rare has that a plain crosshatch does not.
            var x = -span / 2
            while x < span / 2 {
                var y = -span / 2
                while y < span / 2 {
                    let point = CGPoint(x: x, y: y)
                    let dx = (point.x + slide.width) / canvasSize.width
                    let dy = (point.y + slide.height) / canvasSize.height
                    let nearness = max(0, 1 - (dx * dx + dy * dy).squareRoot() * 1.4)
                    if nearness > 0.08 {
                        let r = lineWidth * 1.6
                        context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                                                            width: r * 2, height: r * 2)),
                                     with: .color(.white.opacity(0.25 + 0.7 * nearness)))
                    }
                    y += step
                }
                x += step
            }
        }
    }

    /// Straight-edged shards, clustered around two directions so they read as fractures in a sheet
    /// rather than as scratches.
    private var crackedIce: some View {
        Canvas { context, canvasSize in
            var generator = SeededGenerator(seed: UInt64(abs(seed.hashValue % 100_000)) &+ 31)
            let span = max(canvasSize.width, canvasSize.height) * 1.6
            context.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
            // The facets swing with the light. A fracture that never moves is a printed line.
            context.rotate(by: .degrees((lightX - 0.5) * 14))

            for _ in 0..<22 {
                // Two families, ±34° apart, which is what gives the shattered look its direction.
                let family = generator.nextDouble(in: 0...1) < 0.5 ? -34.0 : 34.0
                let angle = family + generator.nextDouble(in: -9...9)
                let offset = generator.nextDouble(in: -0.55...0.55) * span
                let width = 0.4 + generator.nextDouble(in: 0...1) * 2.2
                let bright = 0.20 + generator.nextDouble(in: 0...1) * 0.55

                var path = Path()
                path.move(to: CGPoint(x: offset, y: -span / 2))
                // One kink part-way down, so a shard is a fracture rather than a ruled line.
                let kink = generator.nextDouble(in: -0.25...0.25) * span
                path.addLine(to: CGPoint(x: offset + kink, y: 0))
                path.addLine(to: CGPoint(x: offset + kink * 0.3, y: span / 2))

                var rotated = context
                rotated.rotate(by: .degrees(angle))
                rotated.stroke(path, with: .color(.white.opacity(bright)), lineWidth: width)
            }
        }
    }

    /// A starfield with two soft clouds behind it. The rarest tier's print.
    private var cosmos: some View {
        Canvas { context, canvasSize in
            var generator = SeededGenerator(seed: UInt64(abs(seed.hashValue % 100_000)) &+ 53)
            // The clouds drift twice as far as the stars, which reads as depth.
            let drift = CGSize(width: (0.5 - lightX) * 0.30 * canvasSize.width,
                               height: (0.5 - lightY) * 0.30 * canvasSize.height)
            for _ in 0..<2 {
                let cx = generator.nextDouble(in: 0.2...0.8) * canvasSize.width + drift.width
                let cy = generator.nextDouble(in: 0.2...0.8) * canvasSize.height + drift.height
                let r = canvasSize.width * (0.28 + generator.nextDouble(in: 0...1) * 0.22)
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.30), .clear]),
                        center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
            }
            for _ in 0..<90 {
                let x = generator.nextDouble(in: 0...1) * canvasSize.width + drift.width * 0.5
                let y = generator.nextDouble(in: 0...1) * canvasSize.height + drift.height * 0.5
                let r = (0.002 + generator.nextDouble(in: 0...1) * 0.006) * canvasSize.width
                let bright = 0.25 + generator.nextDouble(in: 0...1) * 0.6
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(bright)))
            }
        }
    }

    // MARK: - Shine

    /// The rainbow, broken up by scanlines. `.card__shine`.
    private var shine: some View {
        ZStack {
            rainbow
            scanlines.blendMode(.overlay)
        }
        .compositingGroup()
        // The reference's filter, including the direction that matters: saturation comes *down* on
        // the rarer tiers, not up. Neon is what a colour filter looks like.
        .saturation(saturation)
        .contrast(contrast)
        .brightness(0.04 + fromCentre * 0.06)
        .blendMode(.colorDodge)
        .opacity((isLit ? 0.18 + 0.17 * strength : 0.08 + 0.09 * strength) * scaleAttenuation)
    }

    /// Cellophane at the low end, metal at the top.
    private var saturation: Double {
        switch lustre.finish {
        case .matte, .satin: return 0.55
        case .holographic:   return 1.10
        case .prismatic:     return 0.90
        case .radiant:       return 0.75
        }
    }

    private var contrast: Double {
        switch lustre.finish {
        case .matte, .satin: return 1.05
        case .holographic:   return 1.20
        case .prismatic:     return 1.70
        case .radiant:       return 2.20
        }
    }

    /// Three cycles of the spectrum at 110°, oversized so it can travel without exposing an edge.
    private var rainbow: some View {
        let cycles = 3
        let stops: [Gradient.Stop] = (0...(cycles * foilSpectrum.count)).map { i in
            let location = Double(i) / Double(cycles * foilSpectrum.count)
            return .init(color: foilSpectrum[i % foilSpectrum.count], location: location)
        }
        // 2.6 across and 3.5 down, from the reference. The colours have to outrun the pointer.
        let dx = (0.5 - lightX) * 2.6
        let dy = (0.5 - lightY) * 3.5
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
            .rotationEffect(.degrees(110 + phase * 20))
            .scaleEffect(4)
            .offset(x: dx * Double(size), y: dy * Double(size))
    }

    /// One-point ridges. This is the layer that stops the rainbow looking painted on.
    private var scanlines: some View {
        Canvas { context, canvasSize in
            var x: CGFloat = 0
            while x < canvasSize.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 1, height: canvasSize.height)),
                             with: .color(.black))
                context.fill(Path(CGRect(x: x + 1, y: 0, width: 1, height: canvasSize.height)),
                             with: .color(Color(white: 0.4)))
                x += 2
            }
        }
    }

    // MARK: - Pillars

    /// The vertical bars a holo card shows when it is nearly edge-on. `.card__shine:before`.
    ///
    /// Two sets at different periods sliding at different rates, so they beat against each other
    /// rather than marching in step.
    private var pillarField: some View {
        ZStack {
            barField(period: 14, travel: 1.65)
            barField(period: 10, travel: -0.9).blendMode(.screen)
        }
        .compositingGroup()
    }

    private func barField(period: Double, travel: Double) -> some View {
        let bar = 0.03
        var stops: [Gradient.Stop] = []
        var position = 0.0
        while position < 1 {
            stops.append(.init(color: .black, location: min(1, position + bar * 2)))
            stops.append(.init(color: Color(white: 0.7), location: min(1, position + bar * 3)))
            stops.append(.init(color: .black, location: min(1, position + bar * 3.5)))
            stops.append(.init(color: Color(white: 0.7), location: min(1, position + bar * 4)))
            stops.append(.init(color: .black, location: min(1, position + bar * 5)))
            position += bar * period
        }
        stops.append(.init(color: .black, location: 1))
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
            .scaleEffect(x: 2, y: 1)
            .offset(x: (0.5 - lightX) * travel * Double(size))
    }

    // MARK: - Shading

    /// Drives everything away from the light towards black. `.card__shine:after`.
    ///
    /// Without it the whole card fires at once, which is the tell of a texture rather than a
    /// surface. `contrast(4)` is the reference's, and it is what makes the falloff abrupt enough
    /// to read as a highlight rather than a wash.
    private var shading: some View {
        RadialGradient(
            stops: [
                .init(color: Color(white: 0.90).opacity(0.8), location: 0),
                .init(color: Color(white: 0.78).opacity(0.1), location: 0.25),
                .init(color: .black, location: 0.9),
            ],
            center: light, startRadius: 0, endRadius: size * 1.1)
            .contrast(4)
            .brightness(-0.4)
            .blendMode(.luminosity)
            .opacity(0.34 * scaleAttenuation)
    }

    // MARK: - Glitter

    /// The flecks on the rarest tier. Seeded, so a card's glitter is its own.
    private var glitter: some View {
        Canvas { context, canvasSize in
            var generator = SeededGenerator(seed: UInt64(abs(seed.hashValue % 100_000)) &+ 7)
            for _ in 0..<40 {
                let x = generator.nextDouble(in: 0...1)
                let y = generator.nextDouble(in: 0...1)
                let r = (0.004 + generator.nextDouble(in: 0...1) * 0.012) * canvasSize.width
                let dx = x - lightX
                let dy = y - lightY
                let nearness = max(0, 1 - (dx * dx + dy * dy).squareRoot() * 1.9)
                guard nearness > 0.05 else { continue }
                let point = CGPoint(x: x * canvasSize.width, y: y * canvasSize.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(0.20 + 0.75 * nearness)))
            }
        }
        .blendMode(.colorDodge)
        .opacity((isLit ? 0.9 : 0.28) * scaleAttenuation)
    }

    // MARK: - Glare

    /// The specular highlight, verbatim from `.card__glare`.
    private var glare: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(0.8), location: 0.10),
                .init(color: .white.opacity(0.65), location: 0.20),
                .init(color: .black.opacity(0.5), location: 0.90),
            ],
            center: light, startRadius: 0, endRadius: size * 1.2)
            .blendMode(.overlay)
            // Enough to give the surface a direction, not enough to erase the cat under it. The
            // reference is drawing over card art that can afford to be blown out; this is drawing
            // over the one thing the gallery exists to show.
            .opacity((isLit ? 0.42 : 0.16) * scaleAttenuation)
            .allowsHitTesting(false)
    }

    /// The card's edge, which is its own element and gets its own metal.
    ///
    /// Silver up to prismatic and gold at radiant — the same grading the real cards use, and the
    /// one part of the card a collector reads before anything else.
    private var rim: some View {
        let metal: Color = lustre.finish == .radiant
            ? Color(red: 1.0, green: 0.86, blue: 0.45)
            : .white
        return shape.strokeBorder(
            LinearGradient(
                stops: [
                    .init(color: metal.opacity(0.85), location: 0),
                    .init(color: metal.opacity(0.08), location: 0.5),
                    .init(color: metal.opacity(0.7), location: 1),
                ],
                startPoint: light, endPoint: UnitPoint(x: 1 - lightX, y: 1 - lightY)),
            lineWidth: lustre.finish == .radiant ? 1.6 : 1.0)
            .opacity(0.28 + 0.45 * strength)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

extension CatLustre {
    /// What the finish is called, for the stat sheet and the tooltip.
    var finishName: String {
        switch finish {
        case .matte: return L10n.t("catFoil.5fa183b2")
        case .satin: return L10n.t("catFoil.a3175c82")
        case .holographic: return L10n.t("catFoil.846928b3")
        case .prismatic: return L10n.t("catFoil.89ad9eec")
        case .radiant: return L10n.t("catFoil.9d091568")
        }
    }
}
