import PawprintCore

/// A completed gallery cat paired with the small, immutable profile understood by the adventure
/// engine. The original summary remains the source for drawing the portrait in this session; it is
/// never copied into RPG storage.
struct PawpetAdventureCandidate: Identifiable {
    let summary: DailySummary
    let streakDays: Int
    let profile: AdventureCat

    var id: String { summary.day }
}

/// Keeps the existing cat generator and the new pure combat engine on opposite sides of one seam.
///
/// Only four trait families have gameplay meaning. The rest remain visual identity, avoiding an
/// unexplainable combat matrix across the full Pawpet combination space.
@MainActor
enum PawpetAdventureAdapter {
    static func candidate(
        for summary: DailySummary,
        streakDays: Int
    ) -> PawpetAdventureCandidate {
        let traits = PawpetTraits.forDay(summary, streakDays: streakDays)
        let profile = AdventureCat(
            id: summary.day,
            role: role(for: traits.pattern),
            affinity: affinity(for: traits.aura),
            passive: passive(for: traits.expression),
            grade: AdventureGrade(rawValue: traits.rarityGrade) ?? .d
        )
        return PawpetAdventureCandidate(
            summary: summary,
            streakDays: streakDays,
            profile: profile
        )
    }

    /// Pattern is stable for a date, so it decides a cat's durable place in a party.
    static func role(for pattern: PawpetTraits.Pattern) -> AdventureRole {
        switch pattern {
        case .plain, .tuxedo, .bicolor:
            return .guardian
        case .tabby, .spotted, .calico:
            return .striker
        case .colorpoint, .star:
            return .support
        }
    }

    static func affinity(for aura: PawpetTraits.Aura) -> AdventureAffinity {
        switch aura {
        case .dawn: return .dawn
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        case .night: return .night
        case .deepNight: return .deepNight
        }
    }

    /// Expressions alter play style rather than adding another large stat multiplier.
    static func passive(for expression: PawpetTraits.Expression) -> AdventurePassive {
        switch expression {
        case .content, .zen:
            return .steady
        case .sleepy, .tired, .dizzy:
            return .resilient
        case .determined, .focused, .sparkle:
            return .focused
        case .chaotic, .mischief:
            return .opportunist
        case .surprised, .wide:
            return .alert
        }
    }

}
