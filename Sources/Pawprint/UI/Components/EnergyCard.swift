import SwiftUI

/// Translates the day's battery drain into real electrical energy and everyday equivalents.
/// Only battery discharge is counted — while plugged in, macOS doesn't expose actual wall draw,
/// so claiming a total would be a guess.
///
/// The headline rotates. An earlier version always showed `lines.first`, which meant the same two
/// comparisons every single day no matter how many the conversion engine produced.
struct EnergyCard: View {
    let lines: [String]
    let drainedPercent: Int

    /// Randomised at first appearance so two consecutive days don't open on the same line.
    @State private var offset = Int.random(in: 0..<1000)
    private let rotation = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

    private var headline: String? {
        guard !lines.isEmpty else { return nil }
        return lines[offset % lines.count]
    }

    private var secondary: String? {
        guard lines.count > 1 else { return nil }
        return lines[(offset + 1) % lines.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Label(L10n.t("energyCard.1ecc19ad"), systemImage: "bolt.batteryblock.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if lines.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { offset += 1 }
                    } label: {
                        Image(systemName: "shuffle").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("energyCard.2b3d69c1"))
                }
            }

            if let headline {
                Text(headline)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .id(headline)
            }

            if let secondary {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .id(secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .onReceive(rotation) { _ in
            withAnimation(.easeInOut(duration: 0.4)) { offset += 1 }
        }
    }
}
