import SwiftUI

/// Collapsible detail card used for the keyboard / pointer / app breakdowns on the Today tab.
/// Collapsed by default so the popover stays glanceable, per the spec's "가벼운 위젯" goal.
struct BreakdownCard<Content: View>: View {
    let title: String
    let icon: String
    let headline: String
    /// Optional "what does this measure" text, surfaced through an ⓘ next to the title.
    var explanation: String? = nil
    var explanationDetail: String? = nil
    @ViewBuilder var content: () -> Content

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text(title).font(.caption).foregroundStyle(.secondary)
                if let explanation {
                    InfoBadge(title: title, explanation: explanation, detail: explanationDetail)
                }
                Spacer()
                Text(headline).font(.caption.weight(.semibold))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }
    }
}

/// One label/value line inside a `BreakdownCard`.
struct BreakdownRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospacedDigit())
        }
    }
}

/// Horizontal bar showing one app's share of the day's usage.
struct AppUsageBar: View {
    let appName: String
    let seconds: TimeInterval
    let maxSeconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(appName).font(.caption).lineLimit(1)
                Spacer()
                Text(Formatters.compactDuration(Int(seconds)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: maxSeconds > 0 ? max(3, geo.size.width * seconds / maxSeconds) : 3)
            }
            .frame(height: 5)
        }
    }
}
