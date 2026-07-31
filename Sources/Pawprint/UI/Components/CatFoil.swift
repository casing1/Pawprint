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
    /// All three are the reference's `radiant rare` construction, which is a *geometric* pattern
    /// and not the field of random shards a first attempt guessed at. It is a repeating luminance
    /// ramp — stepped 10 → 20 → 35 → 42.5 → 50 → 42.5 → 35 → 20 → 10 → 0 percent across ten bars —
    /// laid at 45°. Crossing two of them at ±45° is what produces the diamond facets that read as
    /// cracked ice, and it is the same trick the rainbow rare uses at a finer pitch.
    ///
    /// The tiers differ in *geometry*, not in strength, so they are told apart at a glance:
    ///
    /// | Tier | Artwork |
    /// |---|---|
    /// | holographic | one family at 45° — plain chevrons |
    /// | prismatic | both families at ±45° — diamond facets |
    /// | radiant | both, finer, with glitter diamonds and a lit centre |
    @ViewBuilder private var subjectPattern: some View {
        switch lustre.finish {
        case .matte, .satin:
            EmptyView()
        case .holographic:
            ramp(angle: 45, period: rampPeriod)
        case .prismatic:
            ZStack {
                ramp(angle: 45, period: rampPeriod)
                ramp(angle: -45, period: rampPeriod).blendMode(.screen)
            }
            .compositingGroup()
        case .radiant:
            ZStack {
                ramp(angle: 45, period: rampPeriod * 0.7)
                ramp(angle: -45, period: rampPeriod * 0.7).blendMode(.screen)
                glitterDiamonds.blendMode(.screen)
                // The reference lights the centre of the facets from the pointer rather than
                // leaving the whole sheet at one brightness.
                RadialGradient(colors: [.white.opacity(0.5), .clear],
                               center: light, startRadius: 0, endRadius: size * 0.55)
                    .blendMode(.screen)
            }
            .compositingGroup()
        }
    }

    /// `hardLight` against the artwork, which is how a ramp of greys becomes light and shade on the
    /// cat rather than a grey film over it.
    private var subjectBlend: BlendMode { .hardLight }

    /// Present at rest, not only under the pointer.
    ///
    /// The first version faded to 0.16 when the pointer was elsewhere, which is why the artwork
    /// looked untouched: a real foil shows its pattern sitting still on a table, and a gallery is
    /// mostly cards nobody is pointing at.
    private var subjectOpacity: Double {
        switch lustre.finish {
        case .matte, .satin: return 0
        case .holographic:   return isLit ? 0.60 : 0.42
        case .prismatic:     return isLit ? 0.72 : 0.52
        case .radiant:       return isLit ? 0.85 : 0.60
        }
    }

    // MARK: - Subject patterns

    /// One period of the ramp, in points.
    ///
    /// The reference's `--barwidth: 1.2%` is a fraction of a 400-point card, so ten bars come to
    /// about 48 points. Held near that on the detail card and only tightened on the thumbnail:
    /// scaling it down proportionally would put five facets inside a cat's head, where the pattern
    /// stops being facets and becomes grey mush.
    private var rampPeriod: Double { max(15, Double(size) * 0.30) }

    /// A `repeating-linear-gradient` with hard steps, which is what makes it read as facets rather
    /// than as a wash. Oversized and rotated, so turning it never exposes an edge.
    private func ramp(angle: Double, period: Double) -> some View {
        // 10 → 20 → 35 → 42.5 → 50 → 42.5 → 35 → 20 → 10 → 0, verbatim from the reference.
        let ladder: [Double] = [0.10, 0.20, 0.35, 0.425, 0.50, 0.425, 0.35, 0.20, 0.10, 0.0]
        let span = Double(size) * 3
        let periods = max(1, Int(span / period))
        var stops: [Gradient.Stop] = []
        for p in 0..<periods {
            for (i, level) in ladder.enumerated() {
                let a = (Double(p) + Double(i) / Double(ladder.count)) / Double(periods)
                let b = (Double(p) + Double(i + 1) / Double(ladder.count)) / Double(periods)
                stops.append(.init(color: Color(white: level), location: min(1, a)))
                stops.append(.init(color: Color(white: level), location: min(1, b)))
            }
        }
        // The sheet slides with the light, so it is a surface being tilted, not a decal.
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
            .frame(width: span, height: span)
            .rotationEffect(.degrees(angle))
            .offset(x: (0.5 - lightX) * 0.35 * Double(size),
                    y: (0.5 - lightY) * 0.35 * Double(size))
    }

    /// The reference's `--glitter`: a lattice of small diamonds, not a scatter of dots.
    private var glitterDiamonds: some View {
        Canvas { context, canvasSize in
            let pitch = max(5, canvasSize.width * 0.075)
            let r = pitch * 0.16
            let slide = CGSize(width: (0.5 - lightX) * 0.2 * canvasSize.width,
                               height: (0.5 - lightY) * 0.2 * canvasSize.height)
            var row = 0
            var y = -pitch
            while y < canvasSize.height + pitch {
                // Every other row offset by half a pitch, which is what makes it a diamond lattice
                // rather than a square grid.
                var x = -pitch + (row % 2 == 0 ? 0 : pitch / 2)
                while x < canvasSize.width + pitch {
                    let cx = x + slide.width
                    let cy = y + slide.height
                    let dx = cx / canvasSize.width - lightX
                    let dy = cy / canvasSize.height - lightY
                    let nearness = max(0, 1 - (dx * dx + dy * dy).squareRoot() * 1.6)
                    if nearness > 0.05 {
                        var diamond = Path()
                        diamond.move(to: CGPoint(x: cx, y: cy - r))
                        diamond.addLine(to: CGPoint(x: cx + r, y: cy))
                        diamond.addLine(to: CGPoint(x: cx, y: cy + r))
                        diamond.addLine(to: CGPoint(x: cx - r, y: cy))
                        diamond.closeSubpath()
                        context.fill(diamond, with: .color(.white.opacity(0.25 + 0.7 * nearness)))
                    }
                    x += pitch
                }
                y += pitch
                row += 1
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
