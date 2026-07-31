import Foundation

/// Builds the pool of lighthearted facts about a day.
///
/// `FunConversions` owns the arithmetic and the regional referents; this decides which comparisons
/// are worth making at all and tags each line with the quantity it describes, so the UI can show a
/// varied set instead of five different ways of saying "you typed".
package enum FunFactBuilder {

    /// Builds the pool of "재미있는 사실". `FunConversions` owns the arithmetic and reference
    /// constants; this decides which categories are worth mentioning and tags each line with the
    /// quantity it describes so the UI can pick a varied set.
    package static func build(raw: DailyRawCounters, summary: DailySummary,
                              machine: MachineFacts) -> [FunFact] {
        var facts: [FunFact] = []

        facts += FunConversions.cursorFacts(meters: summary.cursorDistanceMeters)
        facts += FunConversions.scrollFacts(
            screens: summary.scrollScreens,
            screenHeightMeters: machine.display.screenHeightMetres
        )
        facts += FunConversions.keyboardFacts(
            characterKeys: summary.characterKeyPresses,
            totalKeys: summary.totalKeyPresses
        )
        facts += FunConversions.timeFacts(
            activeSeconds: summary.activeSeconds,
            focusSeconds: summary.totalFocusSeconds,
            screenOnSeconds: summary.screenOnSeconds
        )
        facts += FunConversions.clickFacts(
            totalClicks: summary.totalClicks,
            scrollDirectionChanges: summary.scrollDirectionChanges,
            activeSeconds: summary.activeSeconds
        )
        facts += summary.energyFacts
        facts += FunConversions.networkFacts(
            downloadBytes: summary.networkDownloadBytes,
            uploadBytes: summary.networkUploadBytes,
            peakDownPerSec: summary.peakDownloadBytesPerSec
        )

        func add(_ topic: FunFact.Topic, _ text: String) {
            facts.append(FunFact(topic: topic, text: text))
        }

        // Keyboard character
        if let key = summary.mostPressedKeyLabel, summary.mostPressedKeyCount > 20 {
            add(.keys, L10n.t("statsEngine.18b51aec", key, Formatters.groupedNumber(summary.mostPressedKeyCount)))
        }
        if summary.distinctKeysUsed >= 10 {
            add(.keys, L10n.t("statsEngine.842e6485", summary.distinctKeysUsed))
        }
        if summary.leftHandPercent > 0 {
            let left = summary.leftHandPercent
            if left >= 60 {
                add(.keys, L10n.t("statsEngine.563d76f9", left))
            } else if left <= 40 {
                add(.keys, L10n.t("statsEngine.a12cddd4", 100 - left))
            }
        }
        if let top = summary.keyCategoryCounts.max(by: { $0.value < $1.value }), top.value > 0 {
            add(.keys, L10n.t("statsEngine.75e25f7f", keyCategoryLabel(top.key)))
        }
        if let undo = summary.shortcutCounts[.undo], undo > 5 {
            add(.keys, L10n.t("statsEngine.b22ad129", undo))
        }
        if summary.distinctShortcutsUsed >= 5 {
            add(.keys, L10n.t("statsEngine.1b952ac9", summary.distinctShortcutsUsed))
        }

        // Typing rhythm
        if summary.typingConsistency >= 70 {
            add(.typing, L10n.t("statsEngine.8aed76d6", summary.typingConsistency))
        } else if summary.typingConsistency > 0 && summary.typingConsistency < 35 {
            add(.typing, L10n.t("statsEngine.39b1639d", summary.typingConsistency))
        }
        if let hour = summary.goldenHour, summary.goldenHourWPM > 0 {
            add(.typing, String(format: L10n.t("statsEngine.382a0007"), Formatters.approximateHourLabel(hour), summary.goldenHourWPM))
        }

        // Screen & focus
        if summary.screenOnSeconds > 600, summary.screenUtilizationPercent > 0 {
            add(.screen, L10n.t("statsEngine.355ed757", summary.screenUtilizationPercent))
        }
        if summary.longestBreakSeconds >= 3600 {
            add(.focus, L10n.t("statsEngine.59b909a0", Formatters.compactDuration(summary.longestBreakSeconds)))
        }

        // Pointer detail
        if summary.dragDistanceMeters >= 5 {
            add(.pointer, String(format: L10n.t("statsEngine.8bebeffa"), summary.dragDistanceMeters))
        }

        // Apps
        let totalAppSeconds = summary.appUsage.reduce(0) { $0 + $1.totalSeconds }
        if let app = summary.topApp, totalAppSeconds > 0 {
            let share = min(100, app.totalSeconds / totalAppSeconds * 100)
            if share >= 25 {
                add(.apps, String(format: L10n.t("statsEngine.f0f88eef"), share, app.appName))
            }
        }
        if let typing = summary.topTypingApp, typing.keyPresses > 100 {
            add(.apps, L10n.t("statsEngine.ef798b76", typing.appName, Formatters.compactNumber(typing.keyPresses)))
        }
        if let clicking = summary.topClickingApp, clicking.clicks > 50,
           clicking.bundleID != summary.topTypingApp?.bundleID {
            add(.apps, L10n.t("statsEngine.06245ddb", clicking.appName, Formatters.compactNumber(clicking.clicks)))
        }
        if let typing = summary.topTypingApp, typing.totalInput > 200 {
            add(.apps, L10n.t("statsEngine.806f783a", typing.appName, typing.styleLabel, typing.keyboardSharePercent))
        }

        if summary.shortDwellCount > 20 {
            add(.apps, L10n.t("statsEngine.73aa0650", summary.shortDwellCount))
        }
        if summary.appConcentration >= 50, let app = summary.topApp {
            add(.apps, L10n.t("statsEngine.2e6da40a", app.appName, summary.appConcentration))
        } else if summary.appsToReachHalfTime >= 4 {
            add(.apps, L10n.t("statsEngine.4cb4a4ea", summary.appsToReachHalfTime))
        }

        // Power & device
        if summary.totalChargedPercent > 0 {
            add(.power, L10n.t("statsEngine.fcbeffff", summary.chargeSessionCount, summary.totalChargedPercent))
        }
        if summary.secondsOnBattery > 0 && summary.secondsOnAC > 0 {
            let share = Double(summary.secondsOnBattery) / Double(summary.secondsOnBattery + summary.secondsOnAC) * 100
            add(.power, String(format: L10n.t("statsEngine.5215cd26"), share))
        }
        if let cycles = summary.batteryCycleCount, let health = summary.batteryHealthPercent {
            add(.power, L10n.t("statsEngine.31a632d6", cycles, health))
        }
        if summary.lowPowerModeSeconds > 60 {
            add(.power, L10n.t("statsEngine.39c5d7c6", Formatters.withObjectParticle(Formatters.longDuration(summary.lowPowerModeSeconds))))
        }
        if summary.sleepCount > 0 {
            add(.device, L10n.t("statsEngine.05d2d0d6", summary.sleepCount, summary.wakeCount))
        }
        if summary.lidCloseCount > 0 {
            add(.device, L10n.t("statsEngine.4a261072", summary.lidCloseCount, summary.lidOpenCount))
        }
        if summary.externalDisplayConnectCount > 0 {
            add(.device, L10n.t("statsEngine.ac53b688", summary.externalDisplayConnectCount))
        }
        if summary.audioOutputDeviceChangeCount > 2 {
            add(.device, L10n.t("statsEngine.1bb0264e", summary.audioOutputDeviceChangeCount))
        }

        return facts
    }

    private static func keyCategoryLabel(_ category: KeyCategory) -> String {
        switch category {
        case .character: return L10n.t("statsEngine.50dceb8f")
        case .backspace: return "Backspace"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .enter: return "Enter"
        case .space: return "Space"
        case .tab: return "Tab"
        case .arrow: return L10n.t("statsEngine.820ab339")
        case .shift: return "Shift"
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .capsLock: return "Caps Lock"
        case .hangulSwitch: return L10n.t("statsEngine.0ad7f68d")
        case .functionKey: return L10n.t("statsEngine.119546e6")
        }
    }
}
