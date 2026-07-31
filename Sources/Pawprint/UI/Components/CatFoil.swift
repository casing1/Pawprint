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
struct CatFoil<Content: View>: View {
    let lustre: CatLustre
    /// Distinguishes two cards with the same lustre. The day string is the natural choice.
    let seed: String
    var size: CGFloat

    @ViewBuilder var content: () -> Content

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
            shine
            if lustre.finish >= .prismatic { pillars }
            if isLit { shading }
            if lustre.finish == .radiant { glitter }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
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
    private var pillars: some View {
        ZStack {
            barField(period: 14, travel: 1.65)
            barField(period: 10, travel: -0.9).blendMode(.screen)
        }
        .compositingGroup()
        .brightness(0.12)
        .contrast(1.1)
        .blendMode(.hardLight)
        .opacity((isLit ? 0.34 : 0.12) * scaleAttenuation)
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

    private var rim: some View {
        shape.strokeBorder(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.85), location: 0),
                    .init(color: .white.opacity(0.08), location: 0.5),
                    .init(color: .white.opacity(0.7), location: 1),
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
