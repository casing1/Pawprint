import SwiftUI
import PawprintCore

/// Today measured against the days before it.
///
/// Never framed as a verdict: the comparison says louder or quieter, not better or worse, and a
/// day with nothing to compare against simply shows nothing.
@MainActor
extension TodayView {
    var comparisons: [MetricComparison] {
        let recent = activityCenter.recentSummaries
        guard recent.count >= 2 else { return [] }

        func average(_ keyPath: (DailySummary) -> Double) -> Double {
            recent.map(keyPath).reduce(0, +) / Double(recent.count)
        }
        func isRecord(_ keyPath: (DailySummary) -> Double, today: Double) -> Bool {
            today > 0 && recent.allSatisfy { keyPath($0) < today }
        }

        var result: [MetricComparison] = []

        let keysToday = Double(summary.totalKeyPresses)
        result.append(MetricComparison(
            label: L10n.t("todayView.59ca8aa6"),
            todayValue: keysToday,
            averageValue: average { Double($0.totalKeyPresses) },
            display: Formatters.groupedNumber(summary.totalKeyPresses),
            isRecord: isRecord({ Double($0.totalKeyPresses) }, today: keysToday)
        ))

        let activeToday = Double(summary.activeSeconds)
        result.append(MetricComparison(
            label: L10n.t("todayView.e6bdb45b"),
            todayValue: activeToday,
            averageValue: average { Double($0.activeSeconds) },
            display: Formatters.compactDuration(summary.activeSeconds),
            isRecord: isRecord({ Double($0.activeSeconds) }, today: activeToday)
        ))

        let focusToday = Double(summary.totalFocusSeconds)
        result.append(MetricComparison(
            label: L10n.t("todayView.77bad0ab"),
            todayValue: focusToday,
            averageValue: average { Double($0.totalFocusSeconds) },
            display: Formatters.compactDuration(summary.totalFocusSeconds),
            isRecord: isRecord({ Double($0.totalFocusSeconds) }, today: focusToday)
        ))

        if summary.maxWPM > 0 {
            result.append(MetricComparison(
                label: L10n.t("todayView.99e3df8c"),
                todayValue: summary.maxWPM,
                averageValue: average { $0.maxWPM },
                display: Formatters.wpm(summary.maxWPM),
                isRecord: isRecord({ $0.maxWPM }, today: summary.maxWPM)
            ))
        }

        return result
    }
}
