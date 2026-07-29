import Foundation

/// Deliberately a small, fixed set (spec §7: "칭호는 소수 정예로 제한"). Each one is a
/// pleasant discovery rather than a checklist to grind — nothing in the UI nags about
/// unearned ones beyond showing them dimmed.
///
/// Split in two by `isHidden`. The open ones state their condition up front. The hidden ones
/// show only an empty slot until they fire: their conditions are odd shapes a day happens to
/// fall into rather than targets to aim at, and knowing them in advance would turn a surprise
/// into a chore. None of them treat a day as good or bad — they notice a shape, that is all.
package enum AchievementID: String, Codable, CaseIterable, Identifiable {
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

    // Hidden
    case witchingHour
    case oneHandedWonder
    case tunnelVision
    case stormMinute
    case lidFlipper
    case fullyIndependent
    case perfectBalance
    case fullKeyboard
    case quietKeys

    package var id: String { rawValue }

    /// Shown as an empty slot until unlocked.
    package var isHidden: Bool { Self.hidden.contains(self) }

    static package let hidden: [AchievementID] = [
        .witchingHour, .oneHandedWonder, .tunnelVision, .stormMinute, .lidFlipper,
        .fullyIndependent, .perfectBalance, .fullKeyboard, .quietKeys
    ]

    static package let open: [AchievementID] = allCases.filter { !$0.isHidden }

    package var title: String {
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
        case .witchingHour: return L10n.t("hiddenAchievement.witchingHour.title")
        case .oneHandedWonder: return L10n.t("hiddenAchievement.oneHandedWonder.title")
        case .tunnelVision: return L10n.t("hiddenAchievement.tunnelVision.title")
        case .stormMinute: return L10n.t("hiddenAchievement.stormMinute.title")
        case .lidFlipper: return L10n.t("hiddenAchievement.lidFlipper.title")
        case .fullyIndependent: return L10n.t("hiddenAchievement.fullyIndependent.title")
        case .perfectBalance: return L10n.t("hiddenAchievement.perfectBalance.title")
        case .fullKeyboard: return L10n.t("hiddenAchievement.fullKeyboard.title")
        case .quietKeys: return L10n.t("hiddenAchievement.quietKeys.title")
        }
    }

    package var detail: String {
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
        case .witchingHour: return L10n.t("hiddenAchievement.witchingHour.detail")
        case .oneHandedWonder: return L10n.t("hiddenAchievement.oneHandedWonder.detail")
        case .tunnelVision: return L10n.t("hiddenAchievement.tunnelVision.detail")
        case .stormMinute: return L10n.t("hiddenAchievement.stormMinute.detail")
        case .lidFlipper: return L10n.t("hiddenAchievement.lidFlipper.detail")
        case .fullyIndependent: return L10n.t("hiddenAchievement.fullyIndependent.detail")
        case .perfectBalance: return L10n.t("hiddenAchievement.perfectBalance.detail")
        case .fullKeyboard: return L10n.t("hiddenAchievement.fullKeyboard.detail")
        case .quietKeys: return L10n.t("hiddenAchievement.quietKeys.detail")
        }
    }

    package var icon: String {
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
        case .witchingHour: return "moon.haze.fill"
        case .oneHandedWonder: return "hand.raised.fill"
        case .tunnelVision: return "binoculars.fill"
        case .stormMinute: return "tornado"
        case .lidFlipper: return "laptopcomputer"
        case .fullyIndependent: return "powerplug.portrait.slash"
        case .perfectBalance: return "scalemass.fill"
        case .fullKeyboard: return "pianokeys"
        case .quietKeys: return "speaker.slash.fill"
        }
    }

    package var emoji: String {
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
        case .witchingHour: return "🕯️"
        case .oneHandedWonder: return "🖐️"
        case .tunnelVision: return "🔭"
        case .stormMinute: return "🌪️"
        case .lidFlipper: return "🐚"
        case .fullyIndependent: return "🔋"
        case .perfectBalance: return "⚖️"
        case .fullKeyboard: return "🎹"
        case .quietKeys: return "🤫"
        }
    }
}

package struct UnlockedAchievement: Codable, Identifiable, Hashable {
    package var id: String { achievementID }
    package var achievementID: String
    package var unlockedOn: String
    package var unlockedAt: Date
}
