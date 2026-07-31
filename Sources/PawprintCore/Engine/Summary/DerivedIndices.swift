import Foundation

/// The two indices and the day's tags — 0…100 figures that are deliberately lighthearted rather
/// than scientific, and never framed as a judgement.
package enum DerivedIndices {

    package static func regret(raw: DailyRawCounters, backspaceRatio: Double) -> Double {
        let undo = Double(raw.shortcutCounts[ShortcutType.undo.rawValue] ?? 0)
        let redo = Double(raw.shortcutCounts[ShortcutType.redo.rawValue] ?? 0)
        let selectAll = Double(raw.shortcutCounts[ShortcutType.selectAll.rawValue] ?? 0)
        let rawScore = undo * 3 + redo * 2 + selectAll * 1 + backspaceRatio * 100 * 0.6
        return min(100, rawScore)
    }

    /// How scattered the day was, 0...100.
    ///
    /// Every term is a **rate or a ratio**, never a raw count. The previous version added
    /// `shortDwellCount * 2 + interruptions * 1.5` straight into the score, and both of those grow
    /// with how long the Mac was used — so an eight-hour day pinned the index at 100 no matter how
    /// calmly it was spent, and the number stopped saying anything. Two hundred short app visits
    /// over eight hours is a normal working day; two hundred in one hour is not, and only the
    /// second is chaos.
    ///
    /// Each facet is scaled against a reference value that stands for "about as scattered as this
    /// gets", clamped to 0...1, then combined by weight. Reaching 100 means maxing out all four
    /// at once, which is the point: it should be a remark about an unusual day, not the default.
    package static func chaos(raw: DailyRawCounters) -> Double {
        let hours: Double
        if let first = raw.firstActivity, let last = raw.lastActivity, last > first {
            hours = max(last.timeIntervalSince(first) / 3600, 0.25)
        } else {
            hours = 0
        }
        guard hours > 0 else { return 0 }

        func scaled(_ value: Double, reference: Double) -> Double {
            min(1, max(0, value / reference))
        }

        // One app switch a minute, sustained, is about as restless as a day gets.
        let switching = scaled(Double(raw.totalAppSwitches) / hours, reference: 60)
        // What share of app visits were fleeting — a ratio already, so day length cancels out.
        let shortDwell = raw.totalAppSwitches > 0
            ? scaled(Double(raw.shortDwellCount) / Double(raw.totalAppSwitches), reference: 0.6)
            : 0
        let interrupting = scaled(Double(raw.focusInterruptionsByApp.values.reduce(0, +)) / hours,
                                  reference: 12)
        let burstiness = burstinessScore(raw.activityPerMinute)

        let weighted = switching * 0.30 + shortDwell * 0.25 + interrupting * 0.25 + burstiness * 0.20
        return min(100, weighted * 100)
    }

    /// How spiky the minute-by-minute activity is relative to its own average — a crude proxy
    /// for "sudden bursts of activity" without claiming to detect the user's actual mood.
    private static func burstinessScore(_ perMinute: [Int]) -> Double {
        let nonZero = perMinute.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        let avg = Double(nonZero.reduce(0, +)) / Double(nonZero.count)
        guard avg > 0, let peak = nonZero.max() else { return 0 }
        return min(3, Double(peak) / avg) / 3
    }

    /// Picks the day's tags. Candidates are scored per facet and only the strongest from each
    /// facet survives, so a day is never described three different ways of saying "you typed".
    package static func activityTags(raw: DailyRawCounters, summary: DailySummary) -> [ActivityTag] {
        var candidates: [(tag: ActivityTag, strength: Double)] = []

        func consider(_ tag: ActivityTag, when condition: Bool, strength: Double) {
            if condition { candidates.append((tag, strength)) }
        }

        // Typing style
        consider(.burstTyper,
                 when: summary.maxWPM > 55 && summary.avgWPM > 0 && summary.maxWPM > summary.avgWPM * 1.7,
                 strength: summary.maxWPM / max(summary.avgWPM, 1))
        consider(.steadyTyper,
                 when: raw.characterKeyPresses > 2500 && raw.longestTypingStreakSeconds > 480,
                 strength: Double(summary.typingConsistency) / 50)
        consider(.editorType,
                 when: summary.backspaceRatio > 0.22,
                 strength: summary.backspaceRatio * 4)

        // Pointer style
        consider(.mouseExplorer,
                 when: summary.cursorDistanceMeters > 400,
                 strength: summary.cursorDistanceMeters / 400)
        consider(.scrollTraveler,
                 when: summary.scrollScreens > 300,
                 strength: summary.scrollScreens / 300)

        // Efficiency habits
        let shortcutTotal = raw.shortcutCounts.values.reduce(0, +)
        consider(.shortcutExpert, when: shortcutTotal > 120, strength: Double(shortcutTotal) / 120)
        consider(.pasteHeavy, when: raw.clipboardPasteCount > 35, strength: Double(raw.clipboardPasteCount) / 35)

        // Attention shape
        consider(.focused,
                 when: summary.totalFocusSeconds > 3 * 3600 || summary.longestFocusSeconds > 90 * 60,
                 strength: Double(summary.totalFocusSeconds) / 3600)
        consider(.appHopper,
                 when: raw.totalAppSwitches > 120 || raw.shortDwellCount > 25,
                 strength: Double(raw.totalAppSwitches) / 120)
        consider(.chaotic, when: summary.chaosIndex > 65, strength: summary.chaosIndex / 65)

        // Rhythm of the day
        consider(.nightOwl, when: isNightOwl(raw: raw), strength: 1.5)
        consider(.earlyBird, when: isEarlyBird(raw: raw), strength: 1.4)
        consider(.marathoner, when: summary.activeSeconds > 6 * 3600,
                 strength: Double(summary.activeSeconds) / (6 * 3600))
        consider(.sprinter,
                 when: summary.activeSeconds < 2 * 3600 && summary.totalKeyPresses > 3000,
                 strength: Double(summary.totalKeyPresses) / 3000)

        // Machine & environment
        consider(.unplugged,
                 when: summary.secondsOnBattery > 3 * 3600 && summary.secondsOnBattery > summary.secondsOnAC,
                 strength: Double(summary.secondsOnBattery) / (3 * 3600))
        consider(.multiScreen, when: summary.maxSimultaneousDisplays >= 2,
                 strength: Double(summary.maxSimultaneousDisplays))
        consider(.dataHeavy, when: summary.networkTotalBytes > 3_000_000_000,
                 strength: Double(summary.networkTotalBytes) / 3_000_000_000)
        consider(.screenIdler,
                 when: summary.screenOnSeconds > 3600 && summary.screenUtilizationPercent < 30,
                 strength: Double(100 - summary.screenUtilizationPercent) / 50)

        // Strongest candidate per facet, then the strongest facets overall.
        var best: [ActivityTag.Facet: (tag: ActivityTag, strength: Double)] = [:]
        for candidate in candidates {
            let facet = candidate.tag.facet
            if let existing = best[facet], existing.strength >= candidate.strength { continue }
            best[facet] = candidate
        }

        // `best.values` is a dictionary's, so its order varies per process, and Swift's sort is
        // not stable — two facets of equal strength produced a different set of three tags on
        // different launches. The tag's own name settles it.
        let tags = best.values
            .sorted { lhs, rhs in
                lhs.strength == rhs.strength
                    ? lhs.tag.rawValue < rhs.tag.rawValue
                    : lhs.strength > rhs.strength
            }
            .prefix(3)
            .map(\.tag)

        return tags.isEmpty ? [.steadyTyper] : Array(tags)
    }

    /// Any activity in the early-morning hours, before most of the day gets going.
    private static func isEarlyBird(raw: DailyRawCounters) -> Bool {
        guard let first = raw.firstActivity else { return false }
        let hour = Calendar.current.component(.hour, from: first)
        return hour >= 5 && hour < 8
    }

    private static func isNightOwl(raw: DailyRawCounters) -> Bool {
        let calendar = Calendar.current
        let nightHours: Set<Int> = [0, 1, 2, 3, 4]
        for session in raw.activitySessions {
            if nightHours.contains(calendar.component(.hour, from: session.start)) {
                return true
            }
        }
        return false
    }
}
