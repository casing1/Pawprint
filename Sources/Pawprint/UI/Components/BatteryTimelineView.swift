import SwiftUI
import PawprintCore

/// Sparkline of the day's battery level, with charging stretches tinted differently so a
/// glance shows when the Mac was plugged in.
struct BatteryTimelineView: View {
    let samples: [BatterySample]
    let minLevel: Int?
    let maxLevel: Int?

    private var points: [(x: Double, level: Int, charging: Bool)] {
        guard let first = samples.first?.timestamp,
              let last = samples.last?.timestamp,
              last > first else {
            return samples.enumerated().map { (Double($0.offset), $0.element.level, $0.element.isCharging) }
        }
        let span = last.timeIntervalSince(first)
        return samples.map {
            ($0.timestamp.timeIntervalSince(first) / span, $0.level, $0.isCharging)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L10n.t("batteryTimelineView.40524c64"), systemImage: "battery.100")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let minLevel, let maxLevel {
                    Text("\(minLevel)% ~ \(maxLevel)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            if samples.count < 2 {
                Text(L10n.t("batteryTimelineView.40084ab3"))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(height: 40)
            } else {
                chart.frame(height: 44)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private var chart: some View {
        GeometryReader { geo in
            let pts = points
            ZStack(alignment: .bottomLeading) {
                // 0-100% baseline grid
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    Spacer()
                    Divider().opacity(0.3)
                }

                Path { path in
                    for (index, p) in pts.enumerated() {
                        let x = geo.size.width * p.x
                        let y = geo.size.height * (1 - Double(p.level) / 100)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.green, .yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // Mark charging samples so plugged-in stretches are visible.
                ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                    if p.charging {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 3.5, height: 3.5)
                            .position(
                                x: geo.size.width * p.x,
                                y: geo.size.height * (1 - Double(p.level) / 100)
                            )
                    }
                }
            }
        }
    }
}
