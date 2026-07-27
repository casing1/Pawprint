import SwiftUI

/// "A new version is ready" strip at the top of the popover.
///
/// Distributing outside the App Store means nothing else will ever tell the user a fix exists.
/// Burying that in a settings tab would leave most people on whatever build they first installed,
/// so it surfaces where they already look, and a single tap does the whole job: download, verify,
/// swap, relaunch.
@MainActor
struct UpdateBanner: View {
    @Bindable var updater = UpdateChecker.shared

    var body: some View {
        switch updater.state {
        case .available(let release):
            banner(
                icon: "sparkles",
                title: "새 버전 \(release.version)",
                subtitle: "지금 설치하고 재시작할 수 있어요",
                action: ("업데이트", { Task { await updater.downloadAndInstall(release) } })
            )

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13)).foregroundStyle(Color.accentColor)
                    Text("업데이트 내려받는 중…").font(.caption.weight(.medium))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
                }
                // The relaunch is the surprising part, so it is announced before it happens.
                Text("끝나면 자동으로 설치하고 앱이 다시 시작돼요")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                // Drawn rather than a `ProgressView`, matching the WPM gauge: a shape renders
                // identically everywhere, an AppKit-backed control does not.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.22))
                        Capsule().fill(Color.accentColor)
                            .frame(width: max(3, geo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 5)
                .animation(.easeOut(duration: 0.3), value: progress)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tinted)

        case .readyToInstall(let release):
            banner(
                icon: "checkmark.seal.fill",
                title: "\(release.version) 준비 완료",
                subtitle: "서명 확인됨 — 눌러서 설치",
                action: ("설치하고 재시작", { updater.install() })
            )

        case .failed(let message):
            // Only worth showing once something was actually attempted; a silent background
            // failure (offline, say) shouldn't nag.
            if updater.lastCheckedAt != nil {
                banner(
                    icon: "exclamationmark.triangle.fill",
                    title: "업데이트를 완료하지 못했어요",
                    subtitle: message,
                    action: ("닫기", { updater.dismiss() }),
                    tone: .orange
                )
            }

        case .idle, .checking, .upToDate:
            EmptyView()
        }
    }

    private var tinted: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            )
    }

    private func banner(
        icon: String,
        title: String,
        subtitle: String,
        action: (String, () -> Void),
        tone: Color = .accentColor
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tone)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action.0, action: action.1)
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tone.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tone.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
