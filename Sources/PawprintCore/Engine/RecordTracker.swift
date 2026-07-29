import Foundation
import Observation

/// One metric's all-time best, measured over days *before* today.
package struct PersonalBest {
    package var id: String
    package var title: String
    package var icon: String
    package var best: Double
    package var bestDay: String?
    package var format: (Double) -> String

    package func formatted(_ value: Double) -> String { format(value) }
}

/// Live standing of today's value against the all-time best.
package struct RecordStanding: Identifiable {
    package enum State {
        /// Today has passed the previous all-time best.
        case broken
        /// Close enough that it's worth mentioning — the near-miss is the interesting part.
        case near(Double)   // 0...1 progress toward the record
        case ordinary
    }

    package var id: String { best.id }
    package var best: PersonalBest
    package var todayValue: Double
    package var state: State

    package var progress: Double {
        guard best.best > 0 else { return 0 }
        return min(todayValue / best.best, 1)
    }
}

/// Compares today against personal bests as the day happens, rather than only when the user
/// opens the Records tab.
///
/// The near-miss case is deliberately first-class: "오늘이 최고 기록의 92%" lands harder than
/// finding out after the fact that you missed it. Celebrations are capped at one per record per
/// day so a good session can't turn into a stream of alerts.
/// Not `@MainActor`: it is driven from `ActivityCenter`'s refresh, which runs on the same timer
/// as everything else and is not actor-isolated. Mutation stays on that single path.
@Observable
final package class RecordTracker {
    static package let shared = RecordTracker()

    /// Fraction of the record at which a near-miss becomes worth surfacing.
    static package let nearThreshold = 0.85

    package private(set) var standings: [RecordStanding] = []
    /// Records already celebrated, keyed by "day/metricID". Seeded from persisted settings —
    /// holding it only in memory meant every relaunch re-celebrated the same record, and since
    /// a broken record stays broken for the rest of the day, the banner came back on every
    /// launch, login and post-update restart.
    @ObservationIgnored private var celebrated: Set<String> = []
    /// Set when a record breaks so the UI can fire a celebration once.
    package private(set) var pendingCelebration: RecordStanding?

    private init() {}

    package func clearCelebration() { pendingCelebration = nil }

    /// Builds personal bests from days strictly before today, so today can actually beat them.
    static package func personalBests(fromPastDays past: [DailySummary]) -> [PersonalBest] {
        func best(
            _ id: String, _ title: String, _ icon: String,
            _ value: (DailySummary) -> Double,
            _ format: @escaping (Double) -> String
        ) -> PersonalBest? {
            guard let top = past.max(by: { value($0) < value($1) }), value(top) > 0 else { return nil }
            return PersonalBest(id: id, title: title, icon: icon, best: value(top), bestDay: top.day, format: format)
        }

        return [
            best("maxWPM", L10n.t("recordTracker.99e3df8c"), "bolt.fill", { $0.maxWPM }, { Formatters.wpm($0) }),
            best("totalKeys", L10n.t("recordTracker.92933c2c"), "keyboard", { Double($0.totalKeyPresses) }, { Formatters.compactNumber(Int($0)) }),
            best("activeTime", L10n.t("recordTracker.a1ba9993"), "clock.fill", { Double($0.activeSeconds) }, { Formatters.compactDuration(Int($0)) }),
            best("focusTime", L10n.t("recordTracker.97fff18b"), "target", { Double($0.totalFocusSeconds) }, { Formatters.compactDuration(Int($0)) }),
            best("totalClicks", L10n.t("recordTracker.162ac83e"), "cursorarrow.click", { Double($0.totalClicks) }, { Formatters.compactNumber(Int($0)) }),
            best("cursorDistance", L10n.t("recordTracker.e6ea1cf6"), "figure.run", { $0.cursorDistanceMeters }, { Formatters.compactDistance(meters: $0) }),
        ].compactMap { $0 }
    }

    /// Recomputes standings for today. Cheap enough to call on the summary refresh cadence.
    ///
    /// Returns the updated celebrated-key set when it grew, so the caller can persist it; nil
    /// when nothing changed, so the common path writes nothing.
    @discardableResult
    package func evaluate(today: DailySummary, bests: [PersonalBest], alreadyCelebrated: Set<String>) -> Set<String>? {
        // Keys only ever describe today, so anything older is dead weight.
        celebrated = alreadyCelebrated.union(celebrated).filter { $0.hasPrefix(today.day + "/") }
        let before = celebrated
        var next: [RecordStanding] = []

        for best in bests {
            let value = Self.todayValue(for: best.id, summary: today)
            guard value > 0 else { continue }

            let ratio = best.best > 0 ? value / best.best : 0
            let state: RecordStanding.State
            if ratio > 1 {
                state = .broken
            } else if ratio >= Self.nearThreshold {
                state = .near(ratio)
            } else {
                state = .ordinary
            }

            let standing = RecordStanding(best: best, todayValue: value, state: state)
            next.append(standing)

            if case .broken = state {
                let key = "\(today.day)/\(best.id)"
                if !celebrated.contains(key) {
                    celebrated.insert(key)
                    // In-app confetti only. Beating a personal best is not a *notification*
                    // -worthy event: several of these metrics are cumulative, so a long day
                    // crosses one record after another.
                    pendingCelebration = standing
                }
            }
        }

        // Most interesting first: broken records, then near-misses by closeness.
        standings = next.sorted { lhs, rhs in
            func rank(_ s: RecordStanding) -> Double {
                switch s.state {
                case .broken: return 2
                case .near(let ratio): return 1 + ratio
                case .ordinary: return s.progress
                }
            }
            return rank(lhs) > rank(rhs)
        }

        return celebrated == before ? nil : celebrated
    }

    /// Today's value for a given personal-best id. Kept beside `personalBests` so the two can't
    /// drift apart.
    private static func todayValue(for id: String, summary: DailySummary) -> Double {
        switch id {
        case "maxWPM": return summary.maxWPM
        case "totalKeys": return Double(summary.totalKeyPresses)
        case "activeTime": return Double(summary.activeSeconds)
        case "focusTime": return Double(summary.totalFocusSeconds)
        case "totalClicks": return Double(summary.totalClicks)
        case "cursorDistance": return summary.cursorDistanceMeters
        default: return 0
        }
    }
}
