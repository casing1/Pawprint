import SwiftUI

/// Per-key heatmap drawn on a real US-ANSI keyboard shape, colored by how often each physical
/// key was pressed.
///
/// The underlying data is a frequency table keyed by virtual key code — how many times each
/// position on the board was struck. It carries no ordering and no produced characters, so it
/// can't reconstruct anything that was typed; it's the aggregate the spec explicitly calls for.
struct KeyboardHeatmapView: View {
    let summary: DailySummary

    @State private var hoveredKey: UInt16?

    private var counts: [UInt16: Int] { summary.keyCodeCounts }
    private var maxCount: Int { counts.values.max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if counts.isEmpty {
                Text("아직 키 입력이 기록되지 않았어요")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                keyboard
                insights
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private var header: some View {
        HStack {
            Label("키보드 히트맵", systemImage: "keyboard")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            if let hovered = hoveredKey, let count = counts[hovered] {
                Text("\(KeyboardLayout.label(for: hovered) ?? "?") · \(Formatters.groupedNumber(count))회")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let label = summary.mostPressedKeyLabel {
                Text("최다 \(label) · \(Formatters.groupedNumber(summary.mostPressedKeyCount))회")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var keyboard: some View {
        GeometryReader { geo in
            let unit = geo.size.width / KeyboardLayout.unitsWide
            ZStack(alignment: .topLeading) {
                ForEach(KeyboardLayout.keys) { key in
                    keyCap(key, unit: unit)
                }
            }
        }
        .aspectRatio(KeyboardLayout.unitsWide / KeyboardLayout.unitsTall, contentMode: .fit)
    }

    /// Geometry is precomputed into explicit `CGFloat`s. Leaving the `Double` key-unit values to
    /// mix with `CGFloat` inline made the expression too costly for the type checker.
    private func keyCap(_ key: KeyboardKey, unit: CGFloat) -> some View {
        let count: Int = counts[key.keyCode] ?? 0
        let gap: CGFloat = 1.5
        let unitValue: CGFloat = unit
        let capWidth: CGFloat = max(2, CGFloat(key.width) * unitValue - gap)
        let capHeight: CGFloat = max(2, CGFloat(key.height) * unitValue - gap)
        let offsetX: CGFloat = CGFloat(key.x) * unitValue + gap / 2
        let offsetY: CGFloat = CGFloat(key.y) * unitValue + gap / 2
        let fontSize: CGFloat = max(5, unitValue * 0.34)
        let isHovered: Bool = hoveredKey == key.keyCode
        let strokeColor: Color = isHovered ? Color.primary.opacity(0.6) : Color.clear
        let keyCode: UInt16 = key.keyCode

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(for: count))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .overlay(
                Text(key.label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(labelColor(for: count))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 1)
            )
            .frame(width: capWidth, height: capHeight)
            .offset(x: offsetX, y: offsetY)
            .onHover { inside in
                if inside {
                    hoveredKey = keyCode
                } else if hoveredKey == keyCode {
                    hoveredKey = nil
                }
            }
    }

    /// Log scaling — a handful of keys (space, backspace) dwarf the rest, and a linear ramp
    /// would leave the whole alphabet looking equally cold.
    private func intensity(for count: Int) -> Double {
        guard count > 0, maxCount > 0 else { return 0 }
        let numerator: Double = log(Double(count) + 1.0)
        let denominator: Double = log(Double(maxCount) + 1.0)
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    private func color(for count: Int) -> Color {
        guard count > 0 else { return Color.gray.opacity(0.16) }
        let t: Double = intensity(for: count)
        let hue: Double = 0.58 - (0.58 * t)      // blue (cold) → red (hot)
        let brightness: Double = 0.55 + (0.35 * t)
        let alpha: Double = 0.30 + (0.70 * t)
        let base = Color(hue: hue, saturation: 0.75, brightness: brightness)
        return base.opacity(alpha)
    }

    private func labelColor(for count: Int) -> Color {
        guard count > 0 else { return Color.secondary.opacity(0.55) }
        return intensity(for: count) > 0.55 ? Color.white : Color.primary.opacity(0.75)
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 6) {
            handBalance

            if !summary.keyRowShares.isEmpty {
                HStack(spacing: 6) {
                    ForEach(KeyboardKey.Row.allCases, id: \.self) { row in
                        if let share = summary.keyRowShares[row], share > 0 {
                            Text("\(row.label) \(share)%")
                                .font(.system(size: 9))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        }
                    }
                }
            }

            Text("어떤 자리의 키를 몇 번 눌렀는지만 셉니다. 입력 순서나 내용은 저장하지 않아요.")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private var handBalance: some View {
        let left = summary.leftHandPercent
        let right = 100 - left
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("왼손 \(left)%").font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Text("오른손 \(right)%").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: max(2, geo.size.width * Double(left) / 100))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.opacity(0.6))
                }
            }
            .frame(height: 5)
        }
    }
}
