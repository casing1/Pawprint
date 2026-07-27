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

    @State private var expanded = false
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
                Label("오늘 쓴 전력", systemImage: "bolt.batteryblock.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if lines.count > 1 {
                    Text("\(lines.count)가지 비유")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { offset += 1 }
                    } label: {
                        Image(systemName: "shuffle").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("다른 비유 보기")
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            if let headline {
                Text(headline)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .id(headline)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(lines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 3)
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("배터리로 사용한 전력만 계산했어요 (충전 중 소비는 OS가 알려주지 않아요). 모두 근사치예요.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let secondary {
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
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }
        .onReceive(rotation) { _ in
            guard !expanded else { return }
            withAnimation(.easeInOut(duration: 0.4)) { offset += 1 }
        }
    }
}
