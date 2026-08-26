import SwiftUI
import PawprintCore

enum AdventureExpeditionPresentation {
    /// Keeps the center's party/recommendation order untouched while presenting rarity from
    /// highest to lowest. Enumerated offsets make equal-grade ordering explicitly stable; the
    /// catalog already supplies those cats newest-first.
    static func gradeSortedCandidates(
        _ candidates: [PawpetAdventureCandidate]
    ) -> [PawpetAdventureCandidate] {
        candidates.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = gradeRank(lhs.element.profile.grade)
                let rhsRank = gradeRank(rhs.element.profile.grade)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func gradeRank(_ grade: AdventureGrade) -> Int {
        switch grade {
        case .s: return 0
        case .a: return 1
        case .b: return 2
        case .c: return 3
        case .d: return 4
        }
    }

    static func roleName(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return L10n.t("adventure.role.guardian")
        case .striker: return L10n.t("adventure.role.striker")
        case .support: return L10n.t("adventure.role.support")
        }
    }

    static func roleIcon(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return "shield.fill"
        case .striker: return "bolt.fill"
        case .support: return "heart.fill"
        }
    }

    static func roleColor(_ role: AdventureRole) -> Color {
        switch role {
        case .guardian: return .blue
        case .striker: return .orange
        case .support: return .green
        }
    }

    static func affinityName(_ affinity: AdventureAffinity) -> String {
        switch affinity {
        case .dawn: return L10n.t("adventure.affinity.dawn")
        case .morning: return L10n.t("adventure.affinity.morning")
        case .afternoon: return L10n.t("adventure.affinity.afternoon")
        case .evening: return L10n.t("adventure.affinity.evening")
        case .night: return L10n.t("adventure.affinity.night")
        case .deepNight: return L10n.t("adventure.affinity.deepNight")
        }
    }

    static func passiveName(_ passive: AdventurePassive) -> String {
        switch passive {
        case .steady: return L10n.t("adventure.passive.steady")
        case .resilient: return L10n.t("adventure.passive.resilient")
        case .focused: return L10n.t("adventure.passive.focused")
        case .opportunist: return L10n.t("adventure.passive.opportunist")
        case .alert: return L10n.t("adventure.passive.alert")
        }
    }

    static func skillName(_ role: AdventureRole) -> String {
        switch role {
        case .guardian:
            return L10n.t("adventure.expedition.skill.guardian")
        case .striker:
            return L10n.t("adventure.expedition.skill.striker")
        case .support:
            return L10n.t("adventure.expedition.skill.support")
        }
    }

    static func intentName(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike:
            return L10n.t(
                "adventure.battle.intent.heavyStrike.name"
            )
        case .guardedStance:
            return L10n.t(
                "adventure.battle.intent.guardedStance.name"
            )
        case .drainingMist:
            return L10n.t(
                "adventure.battle.intent.drainingMist.name"
            )
        }
    }

    static func intentIcon(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike: return "burst.fill"
        case .guardedStance: return "shield.lefthalf.filled"
        case .drainingMist: return "cloud.fog.fill"
        }
    }

    static func intentColor(_ intent: AdventureEnemyIntent) -> Color {
        switch intent {
        case .heavyStrike: return .red
        case .guardedStance: return .blue
        case .drainingMist: return .purple
        }
    }

    static func encounterName(
        stageIndex: Int,
        kind: AdventureExpeditionStageKind
    ) -> String {
        if kind == .boss {
            return L10n.t("adventure.expedition.enemy.boss")
        }
        return stageIndex == 0
            ? L10n.t("adventure.expedition.enemy.scout")
            : L10n.t("adventure.expedition.enemy.rival")
    }

    static func relicName(_ relic: AdventureExpeditionRelic) -> String {
        L10n.t("adventure.expedition.relic.\(relic.rawValue).name")
    }

    static func relicDescription(
        _ relic: AdventureExpeditionRelic
    ) -> String {
        L10n.t(
            "adventure.expedition.relic.\(relic.rawValue).description"
        )
    }

    static func relicIcon(_ relic: AdventureExpeditionRelic) -> String {
        switch relic {
        case .sharpenedClaw: return "pawprint.fill"
        case .paddedCape: return "shield.fill"
        case .manaBell: return "bell.fill"
        case .warmTea: return "cup.and.saucer.fill"
        case .echoCharm: return "wave.3.right.circle.fill"
        case .healingHerb: return "leaf.fill"
        }
    }

    static func resultTitle(
        _ status: AdventureExpeditionResultStatus
    ) -> String {
        switch status {
        case .completed:
            return L10n.t("adventure.expedition.result.completed")
        case .defeated:
            return L10n.t("adventure.expedition.result.defeated")
        case .withdrew:
            return L10n.t("adventure.expedition.result.withdrew")
        }
    }

    static func resultColor(
        _ status: AdventureExpeditionResultStatus
    ) -> Color {
        switch status {
        case .completed: return .green
        case .defeated: return .red
        case .withdrew: return .orange
        }
    }
}

extension AdventureExpeditionRoute {
    var color: Color {
        switch self {
        case .sunlitTrail: return .orange
        case .signalRooftops: return .purple
        case .midnightArchive: return .blue
        }
    }
}
