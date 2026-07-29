import SwiftUI
import PawprintCore

/// The trading-card finish on a cat's square, drawn from its lustre.
///
/// Every parameter here is continuous in `lustre.value`, deliberately. Bands alone would only
/// separate five groups, and a settled user earns most of their days inside one of them — the sheen
/// angle, its width, its opacity and above all its *hue* keep moving between two cats three points
/// apart, so the sort order stays visible where a five-way tier would have flattened it.
///
/// Cheap on purpose: static gradients composited over an already-rendered `Canvas`, no timers and
/// no per-frame work, because the gallery draws hundreds of these at once. The only animation is
/// the tilt in `CatFoilTilt`, which is applied to the single large card in the detail sheet.
struct CatFoil: View {
    let lustre: CatLustre
    /// Side of the square this is drawn over. The corner radius and the mask both scale from it.
    var size: CGFloat

    private var cornerRadius: CGFloat { size * 0.15 }

    /// 0–1 across the whole scale, not within the band. The band names the finish; this drives it.
    private var t: Double { (lustre.value / 100).clamped(to: 0...1) }

    /// Matte days get nothing at all — a card that is not special should not shine.
    private var isVisible: Bool { lustre.finish > .matte }

    var body: some View {
        if isVisible {
            ZStack {
                sheen
                if lustre.finish >= .holographic { rainbow }
                if lustre.finish >= .prismatic { sparkleEdge }
            }
            .mask { faceSparingMask }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    /// Keeps the finish off the middle of the card.
    ///
    /// A real foil washes over the whole print, and copying that here cost the thing the card is
    /// for: at 62 points the cat's own colour *is* its identity in the grid, and a full-strength
    /// holo turned a ginger cat and a grey one into the same violet smear. Letting it catch the
    /// light around the edges reads as the same finish and leaves the face legible.
    private var faceSparingMask: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(0.10), location: 0),
                .init(color: .white.opacity(0.35), location: 0.55),
                .init(color: .white, location: 1),
            ],
            center: .center, startRadius: 0, endRadius: size * 0.72)
    }

    /// The base diagonal sweep. Its angle and hue both track lustre, so two cats of the same finish
    /// still catch the light differently.
    private var sheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0), location: 0.30 + 0.12 * t),
                .init(color: .white.opacity(0.06 + 0.13 * t), location: 0.42 + 0.12 * t),
                .init(color: .white.opacity(0), location: 0.54 + 0.12 * t),
                .init(color: .white.opacity(0), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .rotationEffect(.degrees(-24 + 48 * t))
            .blendMode(.screen)
    }

    /// The holographic band. Hue-rotated by the exact lustre value, which is what makes 87.80 and
    /// 93.26 read as different cards rather than as two of the same.
    private var rainbow: some View {
        // A band, not a wash. Covering the whole square tinted the cat instead of finishing the
        // card — the art has to stay the thing you are looking at.
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(hue: 0.00, saturation: 0.85, brightness: 1), location: 0.30),
                .init(color: Color(hue: 0.16, saturation: 0.80, brightness: 1), location: 0.40),
                .init(color: Color(hue: 0.40, saturation: 0.80, brightness: 1), location: 0.50),
                .init(color: Color(hue: 0.58, saturation: 0.85, brightness: 1), location: 0.60),
                .init(color: Color(hue: 0.80, saturation: 0.85, brightness: 1), location: 0.70),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing)
            .hueRotation(.degrees(lustre.value * 3.6))
            .opacity(0.20 + 0.26 * lustre.intensity)
            .rotationEffect(.degrees(-18 + 36 * t))
            .blendMode(.overlay)
    }

    /// A lit rim, brightest on the rarest cards.
    private var sparkleEdge: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.85), .white.opacity(0.15), .white.opacity(0.70)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: lustre.finish == .radiant ? 1.4 : 0.9)
            .opacity(0.35 + 0.45 * lustre.intensity)
            .blendMode(.screen)
    }
}

/// The same finish, tilted towards the pointer.
///
/// Only used where there is one large card and a pointer to track — the detail sheet. Putting this
/// on grid cells would mean a gesture recogniser per thumbnail.
struct CatFoilTilt<Content: View>: View {
    let lustre: CatLustre
    var size: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var tilt: CGSize = .zero

    var body: some View {
        content()
            .overlay {
                CatFoil(lustre: lustre, size: size)
                    .offset(x: tilt.width * 0.35, y: tilt.height * 0.35)
            }
            .rotation3DEffect(.degrees(tilt.height * 0.05), axis: (x: -1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tilt.width * 0.05), axis: (x: 0, y: 1, z: 0))
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                        tilt = CGSize(width: point.x - size / 2, height: point.y - size / 2)
                    }
                case .ended:
                    withAnimation(.easeOut(duration: 0.35)) { tilt = .zero }
                }
            }
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
