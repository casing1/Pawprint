import PawprintCore

/// Builds the completed-cat roster used by both adventure surfaces.
///
/// Reading history stays behind this one explicit boundary. The HUD and expedition center remain
/// event-driven and never poll storage; they receive an immutable roster only when a surface is
/// opened or the Pawprint day changes.
@MainActor
enum AdventureRosterCatalog {
    private struct CacheKey: Equatable {
        let day: String
        let dayStartHour: Int
    }

    private static var cached:
        (key: CacheKey, candidates: [PawpetAdventureCandidate])?

    static func candidates(
        todaySummary: DailySummary,
        dayStartHour: Int,
        rawDays: [DailyRawCounters]? = nil
    ) -> [PawpetAdventureCandidate] {
        let key = CacheKey(
            day: todaySummary.day,
            dayStartHour: dayStartHour
        )
        if rawDays == nil,
           let cached,
           cached.key == key {
            return cached.candidates
        }

        var summaries = (rawDays ?? PawprintStore.shared.allDays())
            .filter { $0.day < todaySummary.day }
            .map {
                SummaryCache.shared.summary(
                    for: $0,
                    dayStartHour: dayStartHour
                )
            }
        summaries.sort { $0.day > $1.day }

        let streaks = StreakRule.streaks(
            for: summaries + [todaySummary]
        )
        let candidates = summaries.map {
            PawpetAdventureAdapter.candidate(
                for: $0,
                streakDays: streaks[$0.day] ?? 0
            )
        }
        if rawDays == nil {
            cached = (key, candidates)
        }
        return candidates
    }

    static func invalidate() {
        cached = nil
    }
}
