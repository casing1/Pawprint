import Foundation

/// Which applications the day was spent in, and what was done in each.
///
/// Bundle identifiers and names never leave the machine — the CSV export deliberately omits them —
/// but they are the most identifying thing recorded, so everything here stays aggregate: seconds,
/// activations and input tallies per app, never a document, a window title or a URL.
package enum AppStats {

    package static func apply(_ raw: DailyRawCounters, to s: inout DailySummary) {
        let appUsage = aggregate(raw.appSessions)
        s.appUsage = appUsage
        s.topApp = appUsage.first
        s.totalAppSwitches = raw.totalAppSwitches
        s.shortDwellCount = raw.shortDwellCount
        if !raw.appSessions.isEmpty {
            s.avgAppDwellSeconds = raw.appSessions.map(\.duration).reduce(0, +) / Double(raw.appSessions.count)
        }

        s.appInputProfiles = inputProfiles(raw: raw, usage: appUsage)
        s.topTypingApp = s.appInputProfiles.filter { $0.keyPresses > 0 }.max { $0.keyPresses < $1.keyPresses }
        s.topClickingApp = s.appInputProfiles.filter { $0.clicks > 0 }.max { $0.clicks < $1.clicks }

        let concentration = concentration(s.appUsage)
        s.appConcentration = concentration.percent
        s.appsToReachHalfTime = concentration.appsForHalf
    }

    private static func aggregate(_ sessions: [AppSessionRecord]) -> [AppUsageStat] {
        var byApp: [String: (name: String, seconds: TimeInterval, count: Int)] = [:]
        for session in sessions {
            var entry = byApp[session.bundleID] ?? (session.appName, 0, 0)
            entry.seconds += session.duration
            entry.count += 1
            byApp[session.bundleID] = entry
        }
        return byApp.map { bundleID, value in
            AppUsageStat(bundleID: bundleID, appName: value.name, totalSeconds: value.seconds, activationCount: value.count)
        }.sorted { lhs, rhs in
            // The bundle identifier breaks ties. Without it two apps with identical time swap
            // places between launches, and `topApp` — the "you spent most of today in" line —
            // names a different one each time.
            lhs.totalSeconds == rhs.totalSeconds
                ? lhs.bundleID < rhs.bundleID
                : lhs.totalSeconds > rhs.totalSeconds
        }
    }

    /// Merges the per-app input tallies into display-ready profiles. App names come from the
    /// stored name map first so history stays readable after an app is uninstalled, falling back
    /// to whatever the usage records know.
    private static func inputProfiles(raw: DailyRawCounters, usage: [AppUsageStat]) -> [AppInputProfile] {
        var bundleIDs = Set(raw.appKeyPresses.keys)
        bundleIDs.formUnion(raw.appClicks.keys)
        bundleIDs.formUnion(raw.appScrollPoints.keys)
        guard !bundleIDs.isEmpty else { return [] }

        let namesFromUsage = Dictionary(usage.map { ($0.bundleID, $0.appName) }, uniquingKeysWith: { a, _ in a })
        return bundleIDs.map { bundleID in
            AppInputProfile(
                bundleID: bundleID,
                appName: raw.appNames[bundleID] ?? namesFromUsage[bundleID] ?? bundleID,
                keyPresses: raw.appKeyPresses[bundleID] ?? 0,
                clicks: raw.appClicks[bundleID] ?? 0,
                scrollPoints: raw.appScrollPoints[bundleID] ?? 0
            )
        }
        .filter { $0.totalInput > 0 }
        // Built from a `Set`, whose order varies per process, then sorted by a key that ties —
        // so the order had two sources of arbitrariness. The identifier settles both.
        .sorted { lhs, rhs in
            lhs.totalInput == rhs.totalInput
                ? lhs.bundleID < rhs.bundleID
                : lhs.totalInput > rhs.totalInput
        }
    }

    /// How concentrated app time was. Uses a Herfindahl index (sum of squared shares), which is
    /// 100 when a single app took everything and approaches 0 when time was spread thin.
    private static func concentration(_ usage: [AppUsageStat]) -> (percent: Int, appsForHalf: Int) {
        let total = usage.reduce(0.0) { $0 + $1.totalSeconds }
        guard total > 0 else { return (0, 0) }

        var herfindahl = 0.0
        var running = 0.0
        var appsForHalf = 0
        for app in usage.sorted(by: { lhs, rhs in
            lhs.totalSeconds == rhs.totalSeconds
                ? lhs.bundleID < rhs.bundleID
                : lhs.totalSeconds > rhs.totalSeconds
        }) {
            let share = app.totalSeconds / total
            herfindahl += share * share
            if running < total / 2 {
                running += app.totalSeconds
                appsForHalf += 1
            }
        }
        return (Int((herfindahl * 100).rounded()), appsForHalf)
    }
}

/// How the day was spent in time: when it started and ended, how much of it was active, and the
/// stretches of uninterrupted work inside it.
package enum TimeStats {

    package static func apply(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.firstActivity = raw.firstActivity
        s.lastActivity = raw.lastActivity
        s.activeSeconds = raw.activeSeconds
        if let first = raw.firstActivity, let last = raw.lastActivity {
            let span = Int(last.timeIntervalSince(first))
            s.idleSeconds = max(0, span - raw.activeSeconds)
        }
        s.activitySessionCount = raw.activitySessions.count
        if !raw.activitySessions.isEmpty {
            s.avgSessionSeconds = raw.activitySessions.map(\.duration).reduce(0, +) / Double(raw.activitySessions.count)
        }
        s.focusSessionCount = raw.focusSessions.count
        s.totalFocusSeconds = Int(raw.focusSessions.map(\.duration).reduce(0, +))
        s.longestFocusSeconds = Int(raw.focusSessions.map(\.duration).max() ?? 0)
        if !raw.focusSessions.isEmpty {
            s.avgFocusSeconds = Double(s.totalFocusSeconds) / Double(raw.focusSessions.count)
        }
        s.bestFocusHour = bestFocusHour(raw.focusSessions)
        s.topInterruptingApp = raw.focusInterruptionsByApp
            .max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
        s.longestBreakSeconds = longestBreak(raw.activitySessions)
    }

    private static func bestFocusHour(_ sessions: [FocusSessionRecord]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        var byHour: [Int: TimeInterval] = [:]
        let calendar = Calendar.current
        for session in sessions {
            let hour = calendar.component(.hour, from: session.start)
            byHour[hour, default: 0] += session.duration
        }
        // The earliest hour wins a tie. Taking the dictionary's maximum unqualified is what
        // made this the one figure that changed when you relaunched the app.
        return byHour.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
    }

    /// Longest gap between consecutive activity sessions — the day's biggest break.
    private static func longestBreak(_ sessions: [ActivitySessionRecord]) -> Int {
        guard sessions.count >= 2 else { return 0 }
        let sorted = sessions.sorted { $0.start < $1.start }
        var longest: TimeInterval = 0
        for (previous, next) in zip(sorted, sorted.dropFirst()) {
            longest = max(longest, next.start.timeIntervalSince(previous.end))
        }
        return Int(max(0, longest))
    }
}
