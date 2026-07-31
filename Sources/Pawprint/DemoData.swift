import Foundation
import PawprintCore

// `#if DEBUG`: this fabricates a history for the README screenshots and has no business in a
// build anyone installs.

#if DEBUG

/// Fabricates a plausible history so the README can show the real app with something in it.
///
/// A screenshot of an empty Pawprint shows nothing about Pawprint. Rather than mocking up the UI,
/// this writes real `DailyRawCounters` into a throwaway database and lets the actual engines derive
/// everything on top — scores, personas, levels, records, achievements, cats. What the screenshots
/// show is therefore what the app genuinely does with a history like this one, not a drawing of it.
///
/// Only compiled-in behaviour is used; there is no separate "demo mode" in the UI to drift from the
/// real thing. The generator is deterministic, so re-running it reproduces the same screenshots.
///
/// **Not shipped as data.** `PAWPRINT_DB` writes it wherever the capture script asks, which is a
/// gitignored scratch directory.
@MainActor
enum DemoData {

    /// A believable working set of apps, weighted so one editor dominates the way a real week does.
    private static let apps: [(bundle: String, name: String, weight: Double)] = [
        ("com.microsoft.VSCode", "Visual Studio Code", 0.34),
        ("com.google.Chrome", "Google Chrome", 0.22),
        ("com.apple.dt.Xcode", "Xcode", 0.14),
        ("com.apple.Terminal", "Terminal", 0.11),
        ("com.tinyspeck.slackmacgap", "Slack", 0.08),
        ("com.figma.Desktop", "Figma", 0.05),
        ("com.apple.mail", "Mail", 0.04),
        ("com.spotify.client", "Spotify", 0.02),
    ]

    /// Letters and punctuation in roughly the proportions English and Korean typing produces, so
    /// the heatmap has a believable shape rather than a flat wash.
    private static let keyWeights: [(code: Int, weight: Double)] = [
        (0, 8.1), (1, 6.3), (2, 4.3), (3, 2.3), (4, 6.1), (5, 2.0), (6, 2.7), (7, 1.0),
        (8, 2.8), (9, 1.0), (11, 1.5), (12, 1.2), (13, 2.4), (14, 12.7), (15, 6.0),
        (16, 5.9), (17, 9.1), (31, 7.5), (32, 2.8), (34, 7.0), (35, 1.9), (37, 4.0),
        (38, 6.7), (40, 0.9), (41, 1.1), (45, 6.7), (46, 2.4), (49, 18.0),
        (36, 5.5), (48, 3.2), (51, 7.8), (53, 0.6), (123, 2.1), (124, 2.0), (125, 1.4), (126, 1.3),
    ]

    /// Writes `days` days ending yesterday, plus a busy partial day for "today".
    static func generate(days: Int = 132) {
        let store = PawprintStore.shared
        let calendar = Calendar.current
        var generator = SeededGenerator(seed: 20_260_301)

        for offset in stride(from: days, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let day = DayKey.string(for: date, dayStartHour: 0)
            // Today is still in progress; a full day's worth of counters at 10am would look wrong.
            let partial = offset == 0
            if let raw = makeDay(day: day, date: date, partial: partial, generator: &generator) {
                store.saveDay(raw)
            }
        }
    }

    /// Returns nil for the occasional day away from the Mac, which is what makes a streak mean
    /// something in the calendar.
    private static func makeDay(day: String, date: Date, partial: Bool,
                                generator: inout SeededGenerator) -> DailyRawCounters? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        // A handful of days off, clustered rather than scattered, so the calendar shows gaps a
        // person would recognise instead of random static.
        let dayIndex = Int(date.timeIntervalSince1970 / 86_400)
        if !partial, dayIndex % 37 == 0 || (isWeekend && dayIndex % 3 == 0) { return nil }

        var raw = DailyRawCounters(day: day)
        let midnight = calendar.startOfDay(for: date)

        // Intensity: weekdays busy, weekends light, with a slow upward drift over the months and
        // a few standout days that produce the records and the S-grade cats.
        let drift = 0.82 + Double(dayIndex % 90) / 300.0
        let standout = dayIndex % 23 == 0
        var intensity = (isWeekend ? 0.22 : 1.0) * drift * (standout ? 1.4 : 1.0)
        // Wide spread on purpose: a heatmap where every square is the same colour says nothing.
        intensity *= 0.35 + generator.nextDouble(in: 0...1) * 1.25
        // Today is the day every screenshot leads with. It runs a full span at high intensity so
        // the score and the ranking agree: a half-finished day can never out-rank complete ones,
        // however hard it is worked, and "an explosive day" sitting beside "calmer than most"
        // is accurate but reads as a contradiction to anyone seeing it for the first time.
        if partial { intensity = 1.75 }

        // A working span, not a waking one. Running 9am to 10pm gave an eleven-hour *active*
        // average, which no one has — the point of the heatmap is that days differ.
        let startHour = isWeekend ? 11 : 9
        let endHour = isWeekend && !partial ? 16 : 18
        let startMinute = startHour * 60 + Int(generator.nextDouble(in: 0...1) * 45)
        let endMinute = min(endHour * 60 + Int(generator.nextDouble(in: 0...1) * 40), 1439)
        guard endMinute > startMinute + 60 else { return nil }

        raw.firstActivity = midnight.addingTimeInterval(TimeInterval(startMinute * 60))
        raw.lastActivity = midnight.addingTimeInterval(TimeInterval(endMinute * 60))

        // MARK: Per-minute shape
        //
        // Two humps with a lunch dip and a fade towards the evening. A flat block of activity is
        // what a fabricated day looks like; this is what a worked one looks like.
        var activeMinutes = 0
        var totalKeys = 0
        var totalChars = 0
        var totalClicks = 0
        var totalScroll = 0.0

        for minute in startMinute...endMinute {
            let hour = Double(minute) / 60
            let morning = exp(-pow(hour - 10.8, 2) / 5.5)
            let afternoon = exp(-pow(hour - 15.4, 2) / 7.0)
            let evening = isWeekend ? 0 : exp(-pow(hour - 20.2, 2) / 3.0) * 0.55
            let lunch = (hour > 12.2 && hour < 13.3) ? 0.18 : 1.0
            var level = (morning + afternoon + evening) * lunch * intensity

            // Most minutes of a working day are not spent at the keyboard: reading, meetings,
            // thinking, coffee. Around 45% land idle, which is what gives the calendar a range
            // instead of a solid block of the darkest colour.
            let roll = generator.nextDouble(in: 0...1)
            if roll < 0.45 {
                level *= roll * 0.12
            } else {
                level *= 0.7 + generator.nextDouble(in: 0...1) * 0.6
            }
            guard level > 0.12 else { continue }

            let keys = Int(level * 95)
            let chars = Int(Double(keys) * (0.62 + generator.nextDouble(in: 0...1) * 0.14))
            let clicks = Int(level * 14)
            let scroll = level * 2_400

            raw.activityPerMinute[minute] = keys + clicks
            raw.charKeysPerMinute[minute] = chars
            raw.clicksPerMinute[minute] = clicks
            raw.scrollPerMinute[minute] = scroll

            if keys + clicks > 0 { activeMinutes += 1 }
            totalKeys += keys
            totalChars += chars
            totalClicks += clicks
            totalScroll += scroll
        }
        guard activeMinutes > 30 else { return nil }

        // MARK: Keyboard
        raw.totalKeyPresses = totalKeys
        raw.characterKeyPresses = totalChars
        let backspaces = Int(Double(totalKeys) * (0.055 + generator.nextDouble(in: 0...1) * 0.045))
        raw.keyCategoryCounts = [
            KeyCategory.character.rawValue: totalChars,
            KeyCategory.backspace.rawValue: backspaces,
            KeyCategory.arrow.rawValue: Int(Double(totalKeys) * 0.07),
            KeyCategory.shift.rawValue: Int(Double(totalKeys) * 0.09),
            KeyCategory.command.rawValue: Int(Double(totalKeys) * 0.05),
            KeyCategory.option.rawValue: Int(Double(totalKeys) * 0.02),
            KeyCategory.space.rawValue: Int(Double(totalKeys) * 0.13),
            KeyCategory.enter.rawValue: Int(Double(totalKeys) * 0.03),
            KeyCategory.tab.rawValue: Int(Double(totalKeys) * 0.02),
            KeyCategory.escape.rawValue: Int(Double(totalKeys) * 0.01),
        ]
        raw.shortcutCounts = [
            ShortcutType.copy.rawValue: Int(Double(totalKeys) * 0.004),
            ShortcutType.paste.rawValue: Int(Double(totalKeys) * 0.004),
            ShortcutType.screenshot.rawValue: Int(Double(totalKeys) * 0.001),
            ShortcutType.undo.rawValue: Int(Double(totalKeys) * 0.002),
            ShortcutType.appSwitch.rawValue: Int(Double(totalKeys) * 0.003),
            ShortcutType.spotlight.rawValue: Int(Double(totalKeys) * 0.001),
            ShortcutType.selectAll.rawValue: Int(Double(totalKeys) * 0.001),
        ]
        let weightTotal = keyWeights.reduce(0) { $0 + $1.weight }
        for entry in keyWeights {
            let share = entry.weight / weightTotal
            raw.keyCodeCounts[String(entry.code)] =
                Int(Double(totalKeys) * share * (0.86 + generator.nextDouble(in: 0...1) * 0.28))
        }
        raw.maxWPM = 74 + generator.nextDouble(in: 0...1) * 34 + (standout ? 12 : 0)
        raw.maxWPMMinute = startMinute + Int(generator.nextDouble(in: 0...1) * Double(endMinute - startMinute))
        raw.longestTypingStreakSeconds = Int(320 + generator.nextDouble(in: 0...1) * 900)
        raw.typingSessionCount = 8 + Int(generator.nextDouble(in: 0...1) * 16)

        // MARK: Pointer
        raw.leftClicks = Int(Double(totalClicks) * 0.87)
        raw.rightClicks = totalClicks - raw.leftClicks
        raw.doubleClicks = Int(Double(totalClicks) * 0.11)
        raw.dragCount = Int(Double(totalClicks) * 0.05)
        raw.cursorDistancePixels = Double(activeMinutes) * (1_500 + generator.nextDouble(in: 0...1) * 1_400)
        raw.maxCursorSpeedPxPerSec = 2_600 + generator.nextDouble(in: 0...1) * 1_800
        raw.scrollUpPoints = totalScroll * (0.46 + generator.nextDouble(in: 0...1) * 0.06)
        raw.scrollDownPoints = totalScroll - raw.scrollUpPoints
        raw.scrollDirectionChanges = Int(Double(activeMinutes) * (1.6 + generator.nextDouble(in: 0...1)))
        raw.maxScrollSpeedPointsPerSec = 3_200 + generator.nextDouble(in: 0...1) * 2_000

        // MARK: Clipboard
        raw.clipboardCopyCount = Int(Double(activeMinutes) * 0.14)
        raw.clipboardPasteCount = Int(Double(activeMinutes) * 0.13)
        raw.clipboardCutCount = Int(Double(activeMinutes) * 0.02)
        raw.clipboardTypeCounts = [
            ClipboardDataType.text.rawValue: raw.clipboardCopyCount - 4,
            ClipboardDataType.image.rawValue: 3,
            ClipboardDataType.file.rawValue: 1,
        ]

        // MARK: Apps
        var cursor = startMinute
        var switches = 0
        while cursor < endMinute {
            let app = weightedApp(&generator)
            let length = max(2, Int(pow(generator.nextDouble(in: 0...1), 2.1) * 46) + 2)
            let end = min(cursor + length, endMinute)
            let session = AppSessionRecord(
                bundleID: app.bundle, appName: app.name,
                start: midnight.addingTimeInterval(TimeInterval(cursor * 60)),
                end: midnight.addingTimeInterval(TimeInterval(end * 60)))
            raw.appSessions.append(session)
            raw.appNames[app.bundle] = app.name
            if end - cursor < 1 { raw.shortDwellCount += 1 }
            let minutesHere = Double(end - cursor)
            raw.appKeyPresses[app.bundle, default: 0] += Int(minutesHere / Double(activeMinutes) * Double(totalKeys))
            raw.appClicks[app.bundle, default: 0] += Int(minutesHere / Double(activeMinutes) * Double(totalClicks))
            raw.appScrollPoints[app.bundle, default: 0] += minutesHere / Double(activeMinutes) * totalScroll
            cursor = end
            switches += 1
        }
        raw.totalAppSwitches = switches
        raw.shortDwellCount += Int(Double(switches) * 0.22)
        raw.appLaunchCounts = ["com.microsoft.VSCode": 2, "com.google.Chrome": 1]

        // MARK: Focus
        var focusCursor = startMinute + 30
        while focusCursor < endMinute - 40 {
            let length = 26 + Int(generator.nextDouble(in: 0...1) * 70)
            let end = min(focusCursor + length, endMinute)
            if end - focusCursor >= 25 {
                raw.focusSessions.append(FocusSessionRecord(
                    start: midnight.addingTimeInterval(TimeInterval(focusCursor * 60)),
                    end: midnight.addingTimeInterval(TimeInterval(end * 60)),
                    primaryApp: "Visual Studio Code",
                    interruptionCount: Int(generator.nextDouble(in: 0...1) * 4)))
            }
            focusCursor = end + 20 + Int(generator.nextDouble(in: 0...1) * 90)
        }
        raw.focusInterruptionsByApp = ["Slack": 6 + Int(generator.nextDouble(in: 0...1) * 8),
                                       "Mail": 2 + Int(generator.nextDouble(in: 0...1) * 4)]

        // MARK: Active time
        raw.activeSeconds = activeMinutes * 60
        var sessionCursor = startMinute
        while sessionCursor < endMinute {
            let length = 20 + Int(generator.nextDouble(in: 0...1) * 75)
            let end = min(sessionCursor + length, endMinute)
            raw.activitySessions.append(ActivitySessionRecord(
                start: midnight.addingTimeInterval(TimeInterval(sessionCursor * 60)),
                end: midnight.addingTimeInterval(TimeInterval(end * 60))))
            sessionCursor = end + 6 + Int(generator.nextDouble(in: 0...1) * 24)
        }

        // MARK: Power, lid, displays
        let onSeconds = (endMinute - startMinute) * 60
        raw.secondsOnBattery = Int(Double(onSeconds) * (isWeekend ? 0.75 : 0.42))
        raw.secondsOnAC = onSeconds - raw.secondsOnBattery
        raw.chargerConnectCount = isWeekend ? 1 : 2
        raw.chargerDisconnectCount = raw.chargerConnectCount
        raw.lidCloseCount = 1 + Int(generator.nextDouble(in: 0...1) * 3)
        raw.lidOpenCount = raw.lidCloseCount
        raw.lidClosedSeconds = raw.lidCloseCount * (900 + Int(generator.nextDouble(in: 0...1) * 2_400))
        raw.lockCount = 2 + Int(generator.nextDouble(in: 0...1) * 4)
        raw.unlockCount = raw.lockCount
        raw.externalDisplayConnectCount = isWeekend ? 0 : 1
        raw.externalDisplayDisconnectCount = raw.externalDisplayConnectCount
        raw.maxSimultaneousDisplays = isWeekend ? 1 : 2
        raw.audioOutputDeviceChangeCount = Int(generator.nextDouble(in: 0...1) * 4)
        raw.displaySleepCount = 2 + Int(generator.nextDouble(in: 0...1) * 3)
        raw.displayWakeCount = raw.displaySleepCount
        raw.screenOnSeconds = min(onSeconds, Int(Double(activeMinutes * 60) * 1.7))
        raw.elevatedThermalSeconds = standout ? 900 : 0

        var level = 88 - Int(generator.nextDouble(in: 0...1) * 10)
        for step in stride(from: startMinute, to: endMinute, by: 30) {
            raw.batterySamples.append(BatterySample(
                timestamp: midnight.addingTimeInterval(TimeInterval(step * 60)),
                level: max(12, level), isCharging: level < 35))
            level += level < 35 ? 9 : -3
            level = min(100, level)
        }

        raw.networkDownloadBytes = UInt64(Double(activeMinutes) * 5_600_000 * (0.5 + generator.nextDouble(in: 0...1)))
        raw.networkUploadBytes = raw.networkDownloadBytes / 7
        raw.peakDownloadBytesPerSec = 4_800_000 + generator.nextDouble(in: 0...1) * 9_000_000
        raw.peakUploadBytesPerSec = 900_000 + generator.nextDouble(in: 0...1) * 1_800_000

        return raw
    }

    private static func weightedApp(_ generator: inout SeededGenerator)
        -> (bundle: String, name: String, weight: Double) {
        let roll = generator.nextDouble(in: 0...1)
        var cumulative = 0.0
        for app in apps {
            cumulative += app.weight
            if roll <= cumulative { return app }
        }
        return apps[0]
    }
}

#endif
