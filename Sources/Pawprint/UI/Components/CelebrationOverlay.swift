import SwiftUI
import PawprintCore

/// Confetti burst used for level-ups and broken records.
///
/// Particles are generated once with fixed randomness and animated by a single published
/// progress value, so the whole burst is one animation rather than N independent timers — it
/// stays cheap enough to sit inside the popover without competing with the tracking work.
struct ConfettiView: View {
    var particleCount: Int = 40
    var duration: Double = 1.6

    private struct Particle: Identifiable {
        let id = UUID()
        let xOffset: CGFloat
        let drift: CGFloat
        let rotation: Double
        let scale: CGFloat
        let color: Color
        let delay: Double
    }

    @State private var progress: CGFloat = 0

    private static let palette: [Color] = [.orange, .yellow, .pink, .cyan, .purple, .green]

    private var particles: [Particle] {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        return (0..<particleCount).map { _ in
            Particle(
                xOffset: CGFloat(generator.nextDouble(in: -0.5...0.5)),
                drift: CGFloat(generator.nextDouble(in: -0.18...0.18)),
                rotation: generator.nextDouble(in: -540...540),
                scale: CGFloat(generator.nextDouble(in: 0.5...1.2)),
                color: Self.palette[generator.nextInt(below: Self.palette.count)],
                delay: generator.nextDouble(in: 0...0.35)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    let local = max(0, min(1, (progress - CGFloat(particle.delay)) / CGFloat(1 - particle.delay)))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(particle.color)
                        .frame(width: 5 * particle.scale, height: 9 * particle.scale)
                        .rotationEffect(.degrees(particle.rotation * Double(local)))
                        .position(
                            x: geo.size.width * (0.5 + particle.xOffset * local) + geo.size.width * particle.drift * local,
                            y: geo.size.height * (0.1 + 1.05 * local * local)
                        )
                        .opacity(local <= 0 ? 0 : Double(1 - local * local))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: duration)) { progress = 1 }
        }
    }
}

/// Banner shown when a personal record falls. Distinct from the quieter level-up banner because
/// beating your own best is the rarer, bigger moment.
struct RecordBrokenBanner: View {
    let standing: RecordStanding
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: standing.best.icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -30))

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t("celebrationOverlay.4995b5f4")).font(.caption.weight(.bold)).foregroundStyle(.orange)
                Text("\(standing.best.title) \(standing.best.formatted(standing.todayValue))")
                    .font(.caption2).foregroundStyle(.primary)
                Text(L10n.t("celebrationOverlay.24276211", standing.best.formatted(standing.best.best)))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
        .overlay(ConfettiView())
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
    }
}

/// Compact "how close am I" row. The near-miss is the point — showing 92% of a record mid-day is
/// more motivating than reporting the miss after midnight.
struct RecordChaseRow: View {
    let standing: RecordStanding

    private var isNear: Bool {
        if case .near = standing.state { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: standing.best.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(isNear ? Color.orange : Color.secondary)
                Text(standing.best.title).font(.caption2)
                Spacer(minLength: 4)
                Text("\(standing.best.formatted(standing.todayValue)) / \(standing.best.formatted(standing.best.best))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(Int(standing.progress * 100))%")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(isNear ? Color.orange : Color.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(isNear
                              ? AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.accentColor.opacity(0.7)))
                        .frame(width: max(2, geo.size.width * standing.progress))
                }
            }
            .frame(height: 4)
        }
    }
}

/// Small deterministic PRNG so generated visuals stay stable across redraws.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state, which would make the generator emit a constant stream.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() % 1_000_000) / 1_000_000
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(below limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        return Int(next() % UInt64(limit))
    }
}
