import SwiftUI
import PawprintCore

/// The hero card at the top of the Today tab: today's playful score, its grade ring, and the
/// day's persona. Framed as a summary of how busy the day looked, never as a rating of the user.
struct ScoreCard: View {
    let score: PawprintScore
    let persona: DailyPersona?

    @State private var animatedProgress: Double = 0

    private var tone: Color {
        switch score.gradeColorHint {
        case .gold: return .orange
        case .green: return .green
        case .blue: return .blue
        case .gray: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                gradeRing

                VStack(alignment: .leading, spacing: 3) {
                    Text(score.headline)
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let persona {
                        Text("\(persona.emoji) \(persona.title)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tone)
                        Text(persona.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            componentBars
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = Double(score.total) / 100
            }
        }
        .onChange(of: score.total) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = Double(newValue) / 100
            }
        }
    }

    private var gradeRing: some View {
        ZStack {
            Circle()
                .stroke(tone.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(colors: [tone.opacity(0.55), tone], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text(score.grade)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(tone)
                Text("\(score.total)")
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 62, height: 62)
    }

    private var componentBars: some View {
        HStack(spacing: 8) {
            ForEach(score.components) { component in
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tone.opacity(0.15))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tone.opacity(0.75))
                                .frame(
                                    height: component.maximum > 0
                                        ? max(2, geo.size.height * Double(component.earned) / Double(component.maximum))
                                        : 2
                                )
                        }
                    }
                    .frame(height: 22)
                    Text(component.label)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
