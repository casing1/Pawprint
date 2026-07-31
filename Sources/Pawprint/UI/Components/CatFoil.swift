import SwiftUI
import PawprintCore

/// A holographic trading-card finish, built the way the real ones are.
///
/// The first attempt was a static gradient sitting on top of the art, which is not what a foil is.
/// A foil is a *response to light*: the rainbow slides across the print as the card turns, a
/// specular glare tracks where the light source is, and the glitter flashes on and off as the angle
/// changes. None of that exists in a still image, which is why the first version read as a colour
/// filter rather than as a finish.
///
/// So this tracks the pointer and treats it as the light. Four layers, composited the way
/// `poke-holo` composites its CSS equivalents:
///
/// 1. **Holo** — a repeating rainbow whose *phase shifts with the pointer*. This is the layer that
///    makes it read as foil: the colours move, they do not merely exist. `.colorDodge`, which is
///    what blows the bright parts out to white the way a real foil does under direct light.
/// 2. **Glare** — a specular highlight centred on the pointer, `.overlay`, so the card looks lit
///    from wherever you are pointing rather than uniformly bright.
/// 3. **Glitter** — a sparse dot field, `.colorDodge` and pointer-shifted, so individual flecks
///    catch and lose the light as the angle changes.
/// 4. **Rim** — a lit edge, which is what actually sells the card as a physical object.
///
/// The pattern differs per finish tier and its phase is seeded from the exact lustre value, so no
/// two cards behave identically.
///
/// **Cost.** At rest a card draws one cheap static layer. Everything above only exists while the
/// pointer is inside that card, and a pointer is inside exactly one card at a time — so a gallery
/// of several hundred pays for one.
struct CatFoil<Content: View>: View {
    let lustre: CatLustre
    /// Distinguishes two cards with the same lustre. The day string is the natural choice.
    let seed: String
    var size: CGFloat
    /// Off for anything being rendered to an image, where there is no pointer to track.
    var interactive: Bool = true

    @ViewBuilder var content: () -> Content

    /// Where the light is, in unit coordinates. `nil` means the pointer is elsewhere.
    @State private var pointer: UnitPoint?

    /// Screenshot capture forces a light position, because a captured window has no pointer in it
    /// and the whole effect would otherwise photograph as its resting state.
    static var forcedPointer: UnitPoint? {
        guard let raw = DebugEnvironment.foilPointer else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return UnitPoint(x: parts[0], y: parts[1])
    }

    private var cornerRadius: CGFloat { size * 0.15 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    /// 0–1 across the whole scale. Drives how strong everything is.
    private var strength: Double { (lustre.value / 100).clamped(to: 0...1) }

    /// A stable per-card offset so two cards of the same tier do not sit in phase.
    private var phase: Double {
        let hash = seed.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        return Double(hash % 360) / 360
    }

    /// Unit position of the light, defaulting to just above the top-left — the direction a card
    /// held in the hand is usually lit from.
    private var light: UnitPoint {
        pointer ?? Self.forcedPointer ?? UnitPoint(x: 0.35, y: 0.2)
    }

    /// The same thing as plain `Double`s. `UnitPoint`'s components are `CGFloat`, and mixing those
    /// with `Double` literals in the same expression leaves `*` ambiguous on a strict type-checker.
    private var lightX: Double { Double(light.x) }
    private var lightY: Double { Double(light.y) }

    private var isLit: Bool { pointer != nil || Self.forcedPointer != nil }

    var body: some View {
        content()
            .overlay { if lustre.finish > .matte { layers } }
            .clipShape(shape)
            .overlay { if lustre.finish >= .holographic { rim } }
            // Tilting towards the light is what makes the moving rainbow legible as a *surface*
            // rather than as an animation playing on a flat panel.
            .rotation3DEffect(.degrees((lightY - 0.5) * -10 * tiltScale),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees((lightX - 0.5) * 10 * tiltScale),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .animation(.easeOut(duration: 0.18), value: pointer)
            .onContinuousHover { phase in
                guard interactive else { return }
                switch phase {
                case .active(let point):
                    pointer = UnitPoint(x: (Double(point.x) / Double(size)).clamped(to: 0...1),
                                        y: (Double(point.y) / Double(size)).clamped(to: 0...1))
                case .ended:
                    pointer = nil
                }
            }
    }

    /// No tilt at rest — a grid of permanently skewed thumbnails looks broken, not shiny.
    private var tiltScale: Double { isLit ? 1 : 0 }

    @ViewBuilder private var layers: some View {
        ZStack {
            holo
            if isLit { glare }
            if lustre.finish >= .prismatic { glitter }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }

    // MARK: - Holo

    /// The repeating rainbow. Its phase is driven by the pointer, which is the whole effect.
    private var holo: some View {
        let stops = holoStops
        let travel = (lightX - 0.5) + (lightY - 0.5)
        return LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
            .scaleEffect(2.2)                                   // room to slide without exposing an edge
            .offset(x: travel * Double(size) * 0.9, y: travel * Double(size) * 0.5)
            .rotationEffect(.degrees(holoAngle))
            .blendMode(.colorDodge)
            // Dodge blows out fast, so the layer is kept dim and lets the blend do the brightening.
            .opacity(isLit ? 0.16 + 0.22 * strength : 0.07 + 0.10 * strength)
    }

    /// Bar spacing and colour set per tier: a satin card gets a soft two-tone sweep, a radiant one
    /// gets the full spectrum at close pitch.
    private var holoStops: [Gradient.Stop] {
        let bands: Int
        let saturation: Double
        switch lustre.finish {
        case .matte, .satin:      bands = 2; saturation = 0.35
        case .holographic:        bands = 4; saturation = 0.70
        case .prismatic:          bands = 6; saturation = 0.85
        case .radiant:            bands = 8; saturation = 1.00
        }
        let perBand = 6
        return (0...(bands * perBand)).map { i in
            let position = Double(i) / Double(bands * perBand)
            let hue = (position * Double(bands) + phase).truncatingRemainder(dividingBy: 1)
            return .init(color: Color(hue: hue, saturation: saturation, brightness: 0.95),
                         location: position)
        }
    }

    private var holoAngle: Double {
        // Fixed per card, so the bars belong to the card rather than swinging with the pointer.
        -35 + phase * 70
    }

    // MARK: - Glare

    /// The specular highlight. Bright where the pointer is, falling to dark at the far corner,
    /// which is what gives the surface a direction.
    private var glare: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(0.55 + 0.25 * strength), location: 0),
                .init(color: .white.opacity(0.18), location: 0.35),
                .init(color: .black.opacity(0.35), location: 1),
            ],
            center: light,
            startRadius: 0, endRadius: size * 0.9)
            .blendMode(.overlay)
    }

    // MARK: - Glitter

    /// Sparse flecks that catch the light. Drawn once into a `Canvas`; the pointer moves the field
    /// slightly so individual dots pass in and out of the glare rather than sitting still.
    private var glitter: some View {
        Canvas { context, canvasSize in
            var generator = SeededGenerator(seed: UInt64(abs(seed.hashValue % 100_000)) &+ 1)
            let count = lustre.finish == .radiant ? 34 : 20
            for _ in 0..<count {
                let x = generator.nextDouble(in: 0...1) * canvasSize.width
                let y = generator.nextDouble(in: 0...1) * canvasSize.height
                let r = (0.006 + generator.nextDouble(in: 0...1) * 0.014) * canvasSize.width
                // Brightest where the light is, so the field reads as reflective rather than as
                // dots printed on the card.
                let dx = Double(x / canvasSize.width) - lightX
                let dy = Double(y / canvasSize.height) - lightY
                let nearness = max(0, 1 - (dx * dx + dy * dy).squareRoot() * 1.6)
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.25 + 0.65 * nearness)))
            }
        }
        .offset(x: (lightX - 0.5) * Double(size) * 0.06, y: (lightY - 0.5) * Double(size) * 0.06)
        .blendMode(.colorDodge)
        .opacity(isLit ? 0.85 : 0.35)
    }

    // MARK: - Rim

    private var rim: some View {
        shape.strokeBorder(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.9), location: 0),
                    .init(color: .white.opacity(0.1), location: 0.45),
                    .init(color: .white.opacity(0.75), location: 1),
                ],
                startPoint: light,
                endPoint: UnitPoint(x: 1 - lightX, y: 1 - lightY)),
            lineWidth: lustre.finish == .radiant ? 1.6 : 1.0)
            .opacity(0.30 + 0.50 * strength)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
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
