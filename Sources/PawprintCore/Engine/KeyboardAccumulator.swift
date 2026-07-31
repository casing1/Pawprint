import Foundation

/// The keyboard's running state, and what a keystroke does to a day.
///
/// Three things here have memory that outlives the event: how long the current typing streak has
/// run, when the last character key was, and which keystrokes fall inside the sixty-second window
/// live WPM is measured over. That state was on `ActivityCenter` beside the database handle, the
/// settings, the day-rollover cursor and the lifetime statistics, which is why none of it could be
/// exercised without the rest.
///
/// A value type mutating a day it is handed. Nothing here reads a clock, a database or a setting:
/// the caller supplies the instant, so "does a two-second gap continue a streak" is a question that
/// can be asked directly instead of by typing at a running application.
package struct KeyboardAccumulator {

    /// Longer than this between two character keys and the streak has ended.
    package static let streakGapSeconds: TimeInterval = 3
    /// The window live WPM is measured over.
    package static let wpmWindowSeconds: TimeInterval = 60
    /// Five characters to a word, by the usual convention.
    package static let charactersPerWord = 5.0

    private var lastCharacterKeyAt: Date?
    private var streakStartedAt: Date?
    /// Character keystrokes inside the WPM window, oldest first.
    private var recentCharacterKeys: [Date] = []

    package init() {}

    /// What the menu bar shows. Recomputed as keys arrive, not on a timer.
    package private(set) var liveWPM: Double = 0

    /// Records one key press into `counters`.
    ///
    /// - Parameters:
    ///   - minute: minute-of-day the caller has already resolved, because that depends on the
    ///     user's day-start hour and is not this type's business.
    ///   - frontmostBundleID: for per-application attribution; `nil` attributes to nothing.
    package mutating func recordKeyPress(category: KeyCategory,
                                         keyCode: UInt16,
                                         at date: Date,
                                         minute: Int,
                                         frontmostBundleID: String?,
                                         into counters: inout DailyRawCounters) {
        counters.totalKeyPresses += 1
        counters.keyCategoryCounts[category.rawValue, default: 0] += 1
        // Frequency only — no ordering, no produced character. Drives the heatmap.
        counters.keyCodeCounts[String(keyCode), default: 0] += 1
        if let bundleID = frontmostBundleID {
            counters.appKeyPresses[bundleID, default: 0] += 1
        }
        counters.activityPerMinute[minute] += 1

        guard category == .character else { return }
        counters.characterKeyPresses += 1
        counters.charKeysPerMinute[minute] += 1
        updateStreak(at: date, into: &counters)
        updateLiveWPM(at: date, minute: minute, into: &counters)
    }

    package mutating func recordShortcut(_ type: ShortcutType, into counters: inout DailyRawCounters) {
        counters.shortcutCounts[type.rawValue, default: 0] += 1
    }

    /// A streak continues while the gaps stay short, and its length is the longest one seen today.
    private mutating func updateStreak(at date: Date, into counters: inout DailyRawCounters) {
        if let last = lastCharacterKeyAt, date.timeIntervalSince(last) <= Self.streakGapSeconds {
            if let start = streakStartedAt {
                counters.longestTypingStreakSeconds = max(counters.longestTypingStreakSeconds,
                                                          Int(date.timeIntervalSince(start)))
            }
        } else {
            streakStartedAt = date
            counters.typingSessionCount += 1
        }
        lastCharacterKeyAt = date
    }

    /// Words per minute over the trailing window.
    ///
    /// The window is trimmed from the front rather than rescanned. It used to be
    /// `removeAll { … }` on every key, which is a full pass and an array compaction each time and
    /// cost 132 µs per keystroke at 96 WPM against 49 µs for a mouse move. The entries are appended
    /// in order, so everything expiring is at the front and one index walk finds it.
    private mutating func updateLiveWPM(at date: Date, minute: Int,
                                        into counters: inout DailyRawCounters) {
        recentCharacterKeys.append(date)
        let cutoff = date.addingTimeInterval(-Self.wpmWindowSeconds)
        var expired = 0
        while expired < recentCharacterKeys.count, recentCharacterKeys[expired] < cutoff {
            expired += 1
        }
        if expired > 0 { recentCharacterKeys.removeFirst(expired) }

        liveWPM = Double(recentCharacterKeys.count) / Self.charactersPerWord
        // Five keys is the floor for calling anything a speed; two keystrokes a second apart are
        // not a 24 WPM day.
        if liveWPM > counters.maxWPM && recentCharacterKeys.count >= 5 {
            counters.maxWPM = liveWPM
            counters.maxWPMMinute = minute
        }
    }

    /// Live WPM decays when nothing is typed, so the menu bar has to be told time passed.
    package mutating func refreshLiveWPM(at date: Date) {
        let cutoff = date.addingTimeInterval(-Self.wpmWindowSeconds)
        var expired = 0
        while expired < recentCharacterKeys.count, recentCharacterKeys[expired] < cutoff {
            expired += 1
        }
        if expired > 0 { recentCharacterKeys.removeFirst(expired) }
        liveWPM = Double(recentCharacterKeys.count) / Self.charactersPerWord
    }

    /// Called when the day rolls over: yesterday's streak does not continue into today.
    package mutating func reset() {
        lastCharacterKeyAt = nil
        streakStartedAt = nil
        recentCharacterKeys.removeAll()
        liveWPM = 0
    }
}
