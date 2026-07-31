import Foundation

/// Everything a day's summary knows about the keyboard.
///
/// Counts and speeds, the heatmap, and the two shape figures — how evenly typing was spread and
/// which hour it was fastest in. Not one line of it depends on the display, the battery or any
/// other part of the summary, which is why it can be a function of the counters alone.
package enum KeyboardStats {

    /// Five characters to a word, by the usual convention.
    private static let charactersPerWord = 5.0

    package static func apply(_ raw: DailyRawCounters,
                              to s: inout DailySummary,
                              dayStartHour: Int) {
        s.totalKeyPresses = raw.totalKeyPresses
        s.characterKeyPresses = raw.characterKeyPresses
        s.maxWPM = raw.maxWPM
        s.longestTypingStreakSeconds = raw.longestTypingStreakSeconds
        s.typingSessionCount = raw.typingSessionCount
        if let minute = raw.maxWPMMinute {
            s.maxWPMTime = DayKey.date(forMinute: minute, day: raw.day, dayStartHour: dayStartHour)
        }
        s.keyCategoryCounts = Dictionary(uniqueKeysWithValues: raw.keyCategoryCounts.compactMap { key, value in
            KeyCategory(rawValue: key).map { ($0, value) }
        })
        s.shortcutCounts = Dictionary(uniqueKeysWithValues: raw.shortcutCounts.compactMap { key, value in
            ShortcutType(rawValue: key).map { ($0, value) }
        })
        let backspaceCount = s.keyCategoryCounts[.backspace] ?? 0
        s.backspaceRatio = raw.totalKeyPresses > 0 ? Double(backspaceCount) / Double(raw.totalKeyPresses) : 0
        s.avgWPM = averageWPM(raw)
        s.distinctShortcutsUsed = raw.shortcutCounts.filter { $0.value > 0 }.count

        s.typingConsistency = consistency(raw.charKeysPerMinute)
        let golden = goldenHour(raw.charKeysPerMinute, dayStartHour: dayStartHour)
        s.goldenHour = golden?.hour
        s.goldenHourWPM = golden?.wpm ?? 0

        applyHeatmap(raw, to: &s)
    }

    /// Averaged over the time actually spent typing, not over all active time.
    ///
    /// The denominator used to be `activeSeconds`, which includes reading, clicking and dragging. A
    /// day of mostly mouse work produced an "average WPM" of two or three — a true statement about
    /// input density, and nothing at all like an average typing speed, which is what the name
    /// promises and what anyone compares against.
    ///
    /// Minutes containing at least one character key are the closest honest denominator the stored
    /// data supports: it needs no new counter, it cannot exceed the day, and it degrades sensibly
    /// for old records, which fall back to the previous figure.
    private static func averageWPM(_ raw: DailyRawCounters) -> Double {
        let typingMinutes = raw.charKeysPerMinute.filter { $0 > 0 }.count
        if typingMinutes > 0 {
            return (Double(raw.characterKeyPresses) / charactersPerWord) / Double(typingMinutes)
        }
        if raw.activeSeconds > 0 {
            return (Double(raw.characterKeyPresses) / charactersPerWord) / (Double(raw.activeSeconds) / 60.0)
        }
        return 0
    }

    private static func applyHeatmap(_ raw: DailyRawCounters, to s: inout DailySummary) {
        s.keyCodeCounts = Dictionary(
            raw.keyCodeCounts.compactMap { key, value -> (UInt16, Int)? in
                guard let code = UInt16(key) else { return nil }
                return (code, value)
            },
            uniquingKeysWith: +
        )
        s.distinctKeysUsed = s.keyCodeCounts.count
        // Lowest key code wins a tie, so "your most pressed key" is the same key tomorrow.
        if let top = s.keyCodeCounts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }) {
            s.mostPressedKeyLabel = KeyboardLayout.label(for: top.key)
            s.mostPressedKeyCount = top.value
        }
        let handAndRow = handAndRowShares(s.keyCodeCounts)
        s.leftHandPercent = handAndRow.leftPercent
        s.keyRowShares = handAndRow.rowShares
    }

    /// Splits keystrokes by which hand normally presses each key, and by keyboard row.
    /// Keys the layout doesn't know about (external/foreign keyboards) are simply skipped.
    private static func handAndRowShares(_ counts: [UInt16: Int]) -> (leftPercent: Int, rowShares: [KeyboardKey.Row: Int]) {
        var left = 0
        var right = 0
        var byRow: [KeyboardKey.Row: Int] = [:]

        for key in KeyboardLayout.keys {
            guard let count = counts[key.keyCode], count > 0 else { continue }
            switch key.hand {
            case .left: left += count
            case .right: right += count
            case .either:
                // Space is pressed by either thumb; split it evenly rather than biasing a side.
                left += count / 2
                right += count - count / 2
            }
            byRow[key.row, default: 0] += count
        }

        let handTotal = left + right
        let leftPercent = handTotal > 0 ? Int((Double(left) / Double(handTotal) * 100).rounded()) : 0

        let rowTotal = byRow.values.reduce(0, +)
        var rowShares: [KeyboardKey.Row: Int] = [:]
        if rowTotal > 0 {
            for (row, value) in byRow {
                rowShares[row] = Int((Double(value) / Double(rowTotal) * 100).rounded())
            }
        }
        return (leftPercent, rowShares)
    }

    /// How evenly typing was spread across the minutes it happened in. Computed as the inverse
    /// of the coefficient of variation, so a steady writer scores high and someone who typed
    /// everything in one frantic burst scores low.
    private static func consistency(_ perMinute: [Int]) -> Int {
        let active = perMinute.filter { $0 > 0 }.map(Double.init)
        guard active.count >= 5 else { return 0 }
        let mean = active.reduce(0, +) / Double(active.count)
        guard mean > 0 else { return 0 }
        let variance = active.reduce(0) { $0 + pow($1 - mean, 2) } / Double(active.count)
        let coefficientOfVariation = variance.squareRoot() / mean
        return max(0, min(100, Int(((1 - min(coefficientOfVariation, 1.5) / 1.5) * 100).rounded())))
    }

    /// The clock hour with the highest sustained typing speed, and that speed in WPM.
    /// Only hours with a meaningful amount of typing are eligible.
    private static func goldenHour(_ charKeysPerMinute: [Int], dayStartHour: Int) -> (hour: Int, wpm: Double)? {
        guard charKeysPerMinute.count == 24 * 60 else { return nil }
        var best: (hour: Int, wpm: Double)?
        for hourIndex in 0..<24 {
            let slice = charKeysPerMinute[(hourIndex * 60)..<((hourIndex + 1) * 60)]
            let typedMinutes = slice.filter { $0 > 0 }.count
            guard typedMinutes >= 5 else { continue }
            let total = slice.reduce(0, +)
            // WPM over the minutes actually spent typing, not the whole hour.
            let wpm = Double(total) / charactersPerWord / Double(typedMinutes)
            if wpm > (best?.wpm ?? 0) {
                let wallHour = (hourIndex + dayStartHour) % 24
                best = (wallHour, wpm)
            }
        }
        return best
    }
}
