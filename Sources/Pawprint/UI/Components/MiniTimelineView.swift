import SwiftUI

/// Compact sparkline of the day's minute-by-minute activity intensity. Tapping expands it to
/// show a coarser hour-by-hour breakdown with labels.
struct MiniTimelineView: View {
    let activityPerMinute: [Int]
    @State private var expanded = false

    private var hourlyBuckets: [Int] {
        guard activityPerMinute.count == 24 * 60 else { return [] }
        return stride(from: 0, to: activityPerMinute.count, by: 60).map { start in
            activityPerMinute[start..<min(start + 60, activityPerMinute.count)].reduce(0, +)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.t("miniTimelineView.43d59c5d"), systemImage: "waveform.path.ecg")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            sparkline
                .frame(height: expanded ? 90 : 36)
                .animation(.easeInOut(duration: 0.2), value: expanded)

            if expanded {
                hourLabels
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture { expanded.toggle() }
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let buckets = hourlyBuckets
            let maxValue = max(buckets.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor.opacity(value == 0 ? 0.15 : 0.85))
                        .frame(height: max(2, geo.size.height * CGFloat(value) / CGFloat(maxValue)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    private var hourLabels: some View {
        HStack {
            Text(L10n.t("miniTimelineView.7a242d5a")).font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Text(L10n.t("miniTimelineView.6b33071a")).font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Text(L10n.t("miniTimelineView.74f80536")).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
