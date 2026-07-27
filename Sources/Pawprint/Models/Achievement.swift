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
        case .firstTenThousandKeys: return L10n.t("achievement.96a8084f")
        case .hundredWPM: return L10n.t("achievement.48a7b7c2")
        case .focusThirtyMinutes: return L10n.t("achievement.4b66a9f3")
        case .focusSixtyMinutes: return L10n.t("achievement.5caa92e1")
        case .cursorOneKilometer: return L10n.t("achievement.5c5e4fba")
        case .scrollSkyscraper: return L10n.t("achievement.07b7522c")
        case .sevenDayStreak: return L10n.t("achievement.89526736")
        case .nightOwl: return L10n.t("achievement.14fb321a")
        case .unpluggedMarathon: return L10n.t("achievement.87c016b4")
        case .multiDisplay: return L10n.t("achievement.143917cc")
        }
    }

    var detail: String {
        switch self {
        case .firstTenThousandKeys: return L10n.t("achievement.f601a386")
        case .hundredWPM: return L10n.t("achievement.9bde8e1b")
        case .focusThirtyMinutes: return L10n.t("achievement.fdc83faa")
        case .focusSixtyMinutes: return L10n.t("achievement.9ebc89eb")
        case .cursorOneKilometer: return L10n.t("achievement.6fd1d603")
        case .scrollSkyscraper: return L10n.t("achievement.623d8857")
        case .sevenDayStreak: return L10n.t("achievement.219c14d5")
        case .nightOwl: return L10n.t("achievement.d2ad9e94")
        case .unpluggedMarathon: return L10n.t("achievement.e38dd7d0")
        case .multiDisplay: return L10n.t("achievement.c7091ec9")
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
