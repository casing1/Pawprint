import XCTest
import PawprintCore
@testable import Pawprint

@MainActor
final class PawpetAdventureAdapterTests: XCTestCase {

    func testRosterDisplaySortsByGradeAndKeepsEqualGradesStable() {
        let candidates = [
            candidate("b-new", grade: .b),
            candidate("s", grade: .s),
            candidate("d", grade: .d),
            candidate("a", grade: .a),
            candidate("b-old", grade: .b),
            candidate("c", grade: .c),
        ]

        let sorted =
            AdventureExpeditionPresentation.gradeSortedCandidates(
                candidates
            )

        XCTAssertEqual(
            sorted.map(\.id),
            ["s", "a", "b-new", "b-old", "c", "d"]
        )
        XCTAssertEqual(
            candidates.map(\.id),
            ["b-new", "s", "d", "a", "b-old", "c"]
        )
    }

    func testEveryPatternHasAnExplicitStableRole() {
        let expectations: [(PawpetTraits.Pattern, AdventureRole)] = [
            (.plain, .guardian),
            (.tabby, .striker),
            (.spotted, .striker),
            (.tuxedo, .guardian),
            (.calico, .striker),
            (.colorpoint, .support),
            (.bicolor, .guardian),
            (.star, .support),
        ]

        XCTAssertEqual(expectations.count, PawpetTraits.Pattern.allCases.count)
        for (pattern, role) in expectations {
            XCTAssertEqual(PawpetAdventureAdapter.role(for: pattern), role)
        }
    }

    func testEveryAuraMapsWithoutLosingItsIdentity() {
        for aura in PawpetTraits.Aura.allCases {
            XCTAssertEqual(
                PawpetAdventureAdapter.affinity(for: aura).rawValue,
                String(describing: aura)
            )
        }
    }

    func testEveryExpressionHasAnExplicitStablePassive() {
        let expectations: [(PawpetTraits.Expression, AdventurePassive)] = [
            (.content, .steady),
            (.sleepy, .resilient),
            (.dizzy, .resilient),
            (.chaotic, .opportunist),
            (.surprised, .alert),
            (.determined, .focused),
            (.focused, .focused),
            (.mischief, .opportunist),
            (.tired, .resilient),
            (.zen, .steady),
            (.wide, .alert),
            (.sparkle, .focused),
        ]

        XCTAssertEqual(expectations.count, PawpetTraits.Expression.allCases.count)
        for (expression, passive) in expectations {
            XCTAssertEqual(PawpetAdventureAdapter.passive(for: expression), passive)
        }
    }

    func testACompletedDayAlwaysProducesTheSameProfile() {
        var summary = DailySummary(day: "2026-07-29")
        summary.totalKeyPresses = 8_000
        summary.activeSeconds = 4 * 3_600
        summary.longestFocusSeconds = 50 * 60
        summary.score = PawprintScore.build(from: summary)

        let first = PawpetAdventureAdapter.candidate(for: summary, streakDays: 7)
        let second = PawpetAdventureAdapter.candidate(for: summary, streakDays: 7)

        XCTAssertEqual(first.profile, second.profile)
        XCTAssertEqual(first.id, summary.day)
    }

    func testEarnedRarityCannotDominateTheRoleStats() {
        var quiet = DailySummary(day: "2026-07-29")
        quiet.score = PawprintScore.build(from: quiet)

        var exceptional = DailySummary(day: quiet.day)
        exceptional.activeSeconds = 6 * 3_600
        exceptional.totalFocusSeconds = 2 * 3_600
        exceptional.totalKeyPresses = 8_000
        exceptional.maxWPM = 100
        exceptional.scrollScreens = 500
        exceptional.totalAppSwitches = 200
        exceptional.score = PawprintScore.build(from: exceptional)

        let low = PawpetAdventureAdapter.candidate(for: quiet, streakDays: 0).profile
        let high = PawpetAdventureAdapter.candidate(for: exceptional, streakDays: 30).profile

        XCTAssertEqual(low.role, high.role)
        XCTAssertEqual(low.grade, .d)
        XCTAssertEqual(high.grade, .s)
        XCTAssertLessThanOrEqual(high.maxHealth - low.maxHealth, 8)
        XCTAssertLessThanOrEqual(high.attack - low.attack, 4)
    }

    private func candidate(
        _ id: String,
        grade: AdventureGrade
    ) -> PawpetAdventureCandidate {
        PawpetAdventureCandidate(
            summary: DailySummary(day: id),
            streakDays: 0,
            profile: AdventureCat(
                id: id,
                role: .guardian,
                affinity: .morning,
                passive: .steady,
                grade: grade
            )
        )
    }
}
