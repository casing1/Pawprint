import AppKit
import SwiftUI

/// Shown before any permission request. Per the spec's privacy principle #8 ("권한 요청 전,
/// 무엇을 수집하지 않는지 먼저 설명한다") — explains what Pawprint never touches *before*
/// asking for Accessibility / Input Monitoring access.
struct PermissionOnboardingView: View {
    @Bindable var permissions = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("🐾").font(.system(size: 28))
                Text("Pawprint 시작하기")
                    .font(.title3.weight(.semibold))
            }

            Text("권한을 요청하기 전에, Pawprint가 **절대 하지 않는 일**을 먼저 알려드릴게요.")
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                bullet("입력한 문자나 비밀번호를 저장하지 않습니다")
                bullet("클립보드 내용을 저장하지 않습니다 (유형만 분류)")
                bullet("화면을 녹화하거나 캡처하지 않습니다")
                bullet("문서·웹페이지 내용을 읽지 않습니다")
                bullet("모든 데이터는 이 Mac에만 저장됩니다")
            }
            .font(.callout)

            Divider()

            Text("대신 키를 눌렀다는 사실, 마우스가 움직인 거리, 어떤 앱을 썼는지 같은 \"횟수와 시간\"만 기록해서 오늘 하루를 재미있는 통계로 보여줘요.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                permissionRow(
                    title: "손동작 접근 권한 (Accessibility)",
                    granted: permissions.accessibilityGranted,
                    request: { permissions.requestAccessibility() },
                    openSettings: { permissions.openAccessibilitySettings() }
                )
                permissionRow(
                    title: "입력 모니터링 권한 (Input Monitoring)",
                    granted: permissions.inputMonitoringGranted,
                    request: { permissions.requestInputMonitoring() },
                    openSettings: { permissions.openInputMonitoringSettings() }
                )
            }
            .padding(.top, 4)

            Text("두 권한 모두 macOS 시스템 설정에서 언제든 취소할 수 있어요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Button("권한 상태 다시 확인") { permissions.refresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button("Pawprint 종료") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Text("방금 시스템 설정에서 권한을 켰는데도 계속 이 화면이 보인다면, 이미 실행 중이던 Pawprint에는 반영되지 않은 것일 수 있어요. Pawprint를 완전히 종료했다가 다시 열어보세요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 360)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.green)
                .font(.caption)
                .padding(.top, 2)
            Text(text)
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, request: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(title)
                .font(.callout)
            Spacer()
            if !granted {
                Button("허용하기") {
                    request()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
