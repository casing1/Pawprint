import SwiftUI

/// Where the day's input actually went, per app, and how each app was driven.
///
/// App *time* alone is misleading — an hour with a document open isn't an hour of work. Splitting
/// each app's input into keyboard vs pointer shows the difference between writing in an editor and
/// browsing in a tab, which is the part people find genuinely revealing.
struct AppInputCard: View {
    let profiles: [AppInputProfile]

    @State private var expanded = false

    private var shown: [AppInputProfile] {
        expanded ? Array(profiles.prefix(8)) : Array(profiles.prefix(3))
    }

    private var maxInput: Int {
        profiles.first?.totalInput ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("앱별 입력", systemImage: "square.stack.3d.up")
                    .font(.caption).foregroundStyle(.secondary)
                InfoBadge(
                    title: "앱별 입력",
                    explanation: "각 앱이 활성화되어 있는 동안의 키 입력과 클릭 횟수를 앱별로 나눠 센 값이에요.",
                    detail: "무엇을 입력했는지, 어디를 클릭했는지는 저장하지 않아요. 제외한 앱은 집계되지 않습니다."
                )
                Spacer()
                if profiles.count > 3 {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: 7) {
                ForEach(shown) { profile in
                    row(profile)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture {
            guard profiles.count > 3 else { return }
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }
    }

    private func row(_ profile: AppInputProfile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(profile.appName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(profile.styleLabel)
                    .font(.system(size: 8))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 4)
                Text("\(Formatters.compactNumber(profile.keyPresses))키 · \(Formatters.compactNumber(profile.clicks))클릭")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Split bar: keyboard share on the left, pointer on the right, scaled by how much
            // input this app received relative to the busiest one.
            GeometryReader { geo in
                let scale = maxInput > 0 ? Double(profile.totalInput) / Double(maxInput) : 0
                let width = max(3, geo.size.width * scale)
                let keyboardFraction = Double(profile.keyboardSharePercent) / 100
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: max(1, width * keyboardFraction))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.opacity(0.6))
                        .frame(width: max(1, width * (1 - keyboardFraction)))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6)
        }
    }
}
