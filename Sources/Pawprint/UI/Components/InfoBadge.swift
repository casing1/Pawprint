import SwiftUI

/// Small "ⓘ" affordance that reveals an explanation on click. Used anywhere the app shows a
/// number whose meaning isn't self-evident — the playful indices especially, where the user
/// deserves to know exactly what went into a score before reading anything into it.
struct InfoBadge: View {
    let title: String
    let explanation: String
    var detail: String? = nil

    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.bold))
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Divider()
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}

/// Canonical descriptions of the derived indices, kept in one place so the popover text and any
/// future copy can't drift apart.
enum MetricExplanations {
    static let regret = (
        title: "후회 지수",
        body: "실행취소(Cmd+Z), 다시실행, 전체선택, 그리고 전체 입력 대비 Backspace 비율을 합쳐 0~100으로 계산해요. 되돌리고 지운 행동이 많을수록 높아집니다.",
        detail: "재미로 보는 지표예요. 실제 후회나 실수를 측정하지 않으며, 높다고 나쁜 게 아니에요 — 퇴고를 많이 한 날일 수도 있죠."
    )

    static let chaos = (
        title: "혼돈 지수",
        body: "시간당 앱 전환 횟수, 5초 미만 짧은 체류, 집중을 끊은 횟수, 그리고 분당 활동량이 얼마나 튀었는지를 합쳐 0~100으로 계산해요.",
        detail: "재미로 보는 지표예요. 바쁘게 여러 일을 오간 날에 높게 나오며, 좋고 나쁨을 뜻하지 않습니다."
    )

    static let score = (
        title: "오늘의 점수",
        body: "활동량(30) + 집중(30) + 타이핑(20) + 속도(20)를 합친 100점 만점 점수예요. 각 항목은 기준치에 가까워질수록 천천히 올라갑니다.",
        detail: "생산성 평가가 아니라 '오늘 얼마나 바빴는지'의 요약이에요. 점수가 낮은 날은 그냥 조용한 날입니다."
    )

    static let persona = (
        title: "오늘의 페르소나",
        body: "키보드 입력 수와 포인터 사용(클릭+스크롤 방향 전환)의 비율, 그리고 단축키 사용 비중으로 그날의 스타일을 붙여요.",
        detail: "날마다 달라지는 태그예요. 사용자를 한 유형으로 규정하지 않습니다."
    )

    static let focus = (
        title: "집중 세션",
        body: "한 앱에서 설정한 시간(기본 5분) 이상 계속 활동한 구간이에요. 다른 앱에 45초 이내로 잠깐 다녀오는 건 끊긴 것으로 보지 않고, 2분 넘게 입력이 없으면 종료됩니다.",
        detail: "기준 시간은 설정 > 수집에서 바꿀 수 있어요."
    )

    static let screenTime = (
        title: "화면 켜짐 시간",
        body: "디스플레이가 실제로 켜져 있던 시간이에요. 절전으로 꺼졌거나 화면이 잠긴 시간은 빠집니다.",
        detail: "'활성 사용시간'은 실제 입력이 있었던 시간이라 보통 더 짧아요. 둘의 차이가 '켜두고 안 쓴 시간'입니다."
    )

    static let network = (
        title: "네트워크 사용량",
        body: "네트워크 인터페이스를 오간 전체 바이트 수예요. 시스템이 제공하는 누적 카운터의 변화량만 읽습니다.",
        detail: "어떤 사이트에 접속했는지, 무엇을 주고받았는지는 전혀 알 수 없고 저장하지도 않아요. 총량만 셉니다."
    )

    static let keyboardHeatmap = (
        title: "키보드 히트맵",
        body: "키보드의 각 자리를 몇 번 눌렀는지 누적한 빈도표예요. 자주 누른 자리일수록 붉게 표시됩니다.",
        detail: "누른 순서도, 실제로 입력된 문자도 저장하지 않아요. '어느 자리를 몇 번' 눌렀는지만 셉니다."
    )

    static let appConcentration = (
        title: "앱 집중도",
        body: "앱 사용시간이 한 앱에 얼마나 몰렸는지를 0~100으로 나타내요. 한 앱만 썼다면 100에 가깝고, 여러 앱에 고루 나뉘면 낮아집니다.",
        detail: "각 앱의 시간 점유율을 제곱해 더한 값(허핀달 지수)이에요."
    )

    static let energy = (
        title: "전력 사용량",
        body: "배터리가 줄어든 양을 이 Mac 배터리의 실제 용량(Wh)으로 환산했어요.",
        detail: "충전기를 꽂고 쓰는 동안의 소비 전력은 macOS가 알려주지 않아서, 배터리로 쓴 만큼만 계산합니다. 모든 환산값은 근사치예요."
    )

    static let level = (
        title: "레벨 시스템",
        body: "각 트랙은 누적 기록을 기준으로 레벨이 오르고, 다음 목표치는 계속 커져요. 끝이 없어서 언제든 다음 단계가 있습니다.",
        detail: "누적값이라 줄어들지 않아요. 쉬어도 레벨이 내려가지 않습니다."
    )
}
