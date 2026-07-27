import Foundation

/// Deliberately a small, fixed set (spec §7: "칭호는 소수 정예로 제한"). Each one is a
/// pleasant discovery rather than a checklist to grind — nothing in the UI nags about
/// unearned ones beyond showing them dimmed.
enum AchievementID: String, Codable, CaseIterable, Identifiable {
    case firstTenThousandKeys
    case hundredWPM
    case focusThirtyMinutes
    case focusSixtyMinutes
    case cursorOneKilometer
    case scrollSkyscraper
    case sevenDayStreak
    case nightOwl
    case unpluggedMarathon
    case multiDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstTenThousandKeys: return "첫 10,000키"
        case .hundredWPM: return "100 WPM 돌파"
        case .focusThirtyMinutes: return "30분 집중"
        case .focusSixtyMinutes: return "60분 집중"
        case .cursorOneKilometer: return "커서 마라토너"
        case .scrollSkyscraper: return "스크롤 등반가"
        case .sevenDayStreak: return "7일 연속 기록"
        case .nightOwl: return "야행성 사용자"
        case .unpluggedMarathon: return "무선 마라토너"
        case .multiDisplay: return "멀티 스크리너"
        }
    }

    var detail: String {
        switch self {
        case .firstTenThousandKeys: return "하루에 10,000키를 입력했어요"
        case .hundredWPM: return "타자 속도 100 WPM을 넘겼어요"
        case .focusThirtyMinutes: return "30분 동안 한 작업에 집중했어요"
        case .focusSixtyMinutes: return "60분 동안 한 작업에 집중했어요"
        case .cursorOneKilometer: return "하루에 커서를 1km 이상 움직였어요"
        case .scrollSkyscraper: return "하루에 화면 1,000개 높이를 스크롤했어요"
        case .sevenDayStreak: return "7일 연속으로 기록을 남겼어요"
        case .nightOwl: return "새벽 시간대에 활동했어요"
        case .unpluggedMarathon: return "충전 없이 4시간 이상 사용했어요"
        case .multiDisplay: return "디스플레이 3개를 동시에 사용했어요"
        }
    }

    var icon: String {
        switch self {
        case .firstTenThousandKeys: return "keyboard.fill"
        case .hundredWPM: return "bolt.fill"
        case .focusThirtyMinutes: return "target"
        case .focusSixtyMinutes: return "scope"
        case .cursorOneKilometer: return "figure.run"
        case .scrollSkyscraper: return "building.2.fill"
        case .sevenDayStreak: return "flame.fill"
        case .nightOwl: return "moon.stars.fill"
        case .unpluggedMarathon: return "battery.100.bolt"
        case .multiDisplay: return "display.2"
        }
    }

    var emoji: String {
        switch self {
        case .firstTenThousandKeys: return "⌨️"
        case .hundredWPM: return "⚡️"
        case .focusThirtyMinutes: return "🎯"
        case .focusSixtyMinutes: return "🧘"
        case .cursorOneKilometer: return "🏃"
        case .scrollSkyscraper: return "🏢"
        case .sevenDayStreak: return "🔥"
        case .nightOwl: return "🦉"
        case .unpluggedMarathon: return "🔋"
        case .multiDisplay: return "🖥️"
        }
    }
}

struct UnlockedAchievement: Codable, Identifiable, Hashable {
    var id: String { achievementID }
    var achievementID: String
    var unlockedOn: String
    var unlockedAt: Date
}
