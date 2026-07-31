import SwiftUI
import PawprintCore

/// The day laid out around a 24-hour dial — midnight at the top, noon at the bottom. Each of the
/// 48 half-hour wedges grows with that slot's activity, which makes a day's rhythm (early bird,
/// night owl, post-lunch dip) legible at a glance in a way a flat sparkline isn't.
struct ActivityClockView: View {
    let activityPerMinute: [Int]
    let dayStartHour: Int

    private static let slotCount = 48   // half-hour resolution

    private var slots: [Double] {
        guard activityPerMinute.count == 24 * 60 else {
            return Array(repeating: 0, count: Self.slotCount)
        }
        let minutesPerSlot = (24 * 60) / Self.slotCount
        // Re-index from day-start back to real clock hours so the dial always matches a wall clock.
        var wallClock = Array(repeating: 0, count: 24 * 60)
        for (index, value) in activityPerMinute.enumerated() {
            let wallMinute = (index + dayStartHour * 60) % (24 * 60)
            wallClock[wallMinute] = value
        }
        return (0..<Self.slotCount).map { slot in
            let start = slot * minutesPerSlot
            return Double(wallClock[start..<(start + minutesPerSlot)].reduce(0, +))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L10n.t("activityClockView.a70de050"), systemImage: "clock.badge.checkmark")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let peak = peakLabel {
                    Text(peak).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                dial
                    .frame(width: 128, height: 128)
                legend
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private var peakLabel: String? {
        let values = slots
        guard let peak = values.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 else { return nil }
        let hour = peak.offset / 2
        return L10n.t("activityClockView.9c405353", Formatters.approximateHourLabel(hour))
    }

    private var dial: some View {
        GeometryReader { geo in
            let values = slots
            let maxValue = max(values.max() ?? 1, 1)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let innerRadius = min(geo.size.width, geo.size.height) * 0.24
            let maxOuter = min(geo.size.width, geo.size.height) * 0.5

            ZStack {
                // Hour ticks every 6 hours for orientation.
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1, height: maxOuter - innerRadius)
                        .offset(y: -(innerRadius + (maxOuter - innerRadius) / 2))
                        .rotationEffect(.degrees(Double(hour) / 24 * 360))
                }

                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)

                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let fraction = (value / maxValue).squareRoot()
                    let length = (maxOuter - innerRadius) * fraction
                    if value > 0 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.45), Color.accentColor],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: max(2, length))
                            .offset(y: -(innerRadius + length / 2))
                            .rotationEffect(.degrees(Double(index) / Double(Self.slotCount) * 360))
                    }
                }

                Text("🐾").font(.system(size: innerRadius * 0.9))
            }
            .position(x: center.x, y: center.y)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(periodBreakdown, id: \.name) { period in
                HStack(spacing: 5) {
                    Text(period.emoji).font(.system(size: 10))
                    Text(period.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        // "Afternoon 12–18" and "Nachmittag 12–18" are half again as long as
                        // "오후 12-18시"; wrapped, they pushed the dial's rows out of alignment.
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(period.percent)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(period.percent > 0 ? .primary : .tertiary)
                }
            }
        }
        // Takes the width the dial leaves rather than a figure measured against Korean. The card is
        // wide enough that the percentages simply align with the rows above it.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Period {
        var name: String
        var emoji: String
        var percent: Int
    }

    /// Share of the day's activity that fell in each rough part of the day.
    private var periodBreakdown: [Period] {
        let values = slots
        let total = values.reduce(0, +)
        func share(_ hourRange: Range<Int>) -> Int {
            guard total > 0 else { return 0 }
            let sum = hourRange.reduce(0.0) { acc, hour in
                acc + values[(hour * 2)] + values[(hour * 2) + 1]
            }
            return Int((sum / total * 100).rounded())
        }
        return [
            Period(name: L10n.t("activityClockView.7f679637"), emoji: "🌙", percent: share(0..<6)),
            Period(name: L10n.t("activityClockView.2c0538b2"), emoji: "🌅", percent: share(6..<12)),
            Period(name: L10n.t("activityClockView.97bdffaf"), emoji: "☀️", percent: share(12..<18)),
            Period(name: L10n.t("activityClockView.78da68f9"), emoji: "🌆", percent: share(18..<24)),
        ]
    }
}
