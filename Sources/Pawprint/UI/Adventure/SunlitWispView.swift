import SwiftUI

/// A code-native training foe for the first adventure.
///
/// Keeping this in SwiftUI lets the battle react immediately to hit and attack phases without
/// adding an image asset pipeline before the combat loop itself has proved fun.
struct SunlitWispView: View {
    let isAttacking: Bool
    let isHit: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.yellow : Color.orange)
                    .frame(width: index.isMultiple(of: 3) ? 7 : 4)
                    .offset(y: -75)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .opacity(0.52)
            }

            Ellipse()
                .fill(Color.orange.opacity(0.16))
                .frame(width: 124, height: 24)
                .offset(y: 66)

            wispBody
        }
        .frame(width: 178, height: 178)
        .offset(
            x: isHit ? 10 : isAttacking ? -34 : 0,
            y: 0
        )
        .rotationEffect(.degrees(isHit ? -7 : isAttacking ? 4 : 0))
        .scaleEffect(isAttacking ? 1.08 : isHit ? 0.92 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.48),
            value: isAttacking
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.35),
            value: isHit
        )
        .accessibilityHidden(true)
    }

    private var wispBody: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.92), Color.orange.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 34)
                    .offset(y: -69)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.48),
                            Color(red: 1.0, green: 0.56, blue: 0.18),
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 86
                    )
                )
                .frame(width: 126, height: 126)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.72), lineWidth: 3)
                        .padding(5)
                }
                .shadow(color: Color.orange.opacity(0.34), radius: 16, y: 7)

            HStack(spacing: 24) {
                eye
                eye
            }
            .offset(y: -9)

            Capsule()
                .fill(Color.brown.opacity(0.72))
                .frame(width: 18, height: 7)
                .offset(y: 22)

            Circle()
                .fill(Color.white.opacity(0.58))
                .frame(width: 22, height: 13)
                .blur(radius: 1)
                .offset(x: -34, y: 34)
        }
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: 25, height: 27)
            Circle()
                .fill(Color.brown)
                .frame(width: 12, height: 15)
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
                .offset(x: -2, y: -4)
        }
    }
}
