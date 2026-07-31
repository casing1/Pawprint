import SwiftUI
import PawprintCore

/// The tables underneath Today: where the day's time and input went, broken down by application,
/// by key and by hour.
///
/// Split out of `TodayView` because it is the half of that file with no relationship to the rest
/// of it — the cards above answer "how was today", these answer "where did it go".
@MainActor
extension TodayView {
    var breakdowns: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("todayView.918f5d1c")).font(.caption).foregroundStyle(.secondary)

            BreakdownCard(
                title: L10n.t("todayView.f1d4069c"),
                icon: "keyboard",
                headline: Formatters.groupedNumber(summary.totalKeyPresses)
            ) {
                BreakdownRow(label: L10n.t("todayView.50dceb8f"), value: Formatters.groupedNumber(summary.characterKeyPresses))
                BreakdownRow(label: L10n.t("todayView.70cb98a7"), value: summary.avgWPM > 0 ? Formatters.wpm(summary.avgWPM) : "-")
                BreakdownRow(label: "Backspace", value: Formatters.groupedNumber(summary.keyCategoryCounts[.backspace] ?? 0))
                BreakdownRow(label: L10n.t("todayView.b1145a2d"), value: String(format: "%.1f%%", summary.backspaceRatio * 100))
                BreakdownRow(label: "Escape", value: Formatters.groupedNumber(summary.keyCategoryCounts[.escape] ?? 0))
                BreakdownRow(label: "Space", value: Formatters.groupedNumber(summary.keyCategoryCounts[.space] ?? 0))
                BreakdownRow(label: "Enter", value: Formatters.groupedNumber(summary.keyCategoryCounts[.enter] ?? 0))
                BreakdownRow(label: L10n.t("todayView.820ab339"), value: Formatters.groupedNumber(summary.keyCategoryCounts[.arrow] ?? 0))
                BreakdownRow(label: L10n.t("todayView.0ad7f68d"), value: Formatters.groupedNumber(summary.keyCategoryCounts[.hangulSwitch] ?? 0))
                Divider().padding(.vertical, 2)
                BreakdownRow(label: L10n.t("todayView.7db54c52"), value: "\(summary.shortcutCounts[.copy] ?? 0) / \(summary.shortcutCounts[.paste] ?? 0)")
                BreakdownRow(label: L10n.t("todayView.799f28ec"), value: Formatters.groupedNumber(summary.shortcutCounts[.cut] ?? 0))
                BreakdownRow(label: "Undo / Redo", value: "\(summary.shortcutCounts[.undo] ?? 0) / \(summary.shortcutCounts[.redo] ?? 0)")
                BreakdownRow(label: L10n.t("todayView.0aa04a70"), value: Formatters.groupedNumber(summary.shortcutCounts[.selectAll] ?? 0))
                BreakdownRow(label: "Spotlight", value: Formatters.groupedNumber(summary.shortcutCounts[.spotlight] ?? 0))
                BreakdownRow(label: L10n.t("todayView.df482b99"), value: Formatters.groupedNumber(summary.shortcutCounts[.screenshot] ?? 0))
                BreakdownRow(label: L10n.t("todayView.8b22d2c9"), value: Formatters.groupedNumber(summary.shortcutCounts[.appSwitch] ?? 0))
                BreakdownRow(label: L10n.t("todayView.84e4f978"), value: Formatters.compactDuration(summary.longestTypingStreakSeconds))
                BreakdownRow(label: L10n.t("todayView.5d0cde8c"), value: "\(summary.typingSessionCount)")
                if summary.fingerTravelMeters >= 1 {
                    BreakdownRow(label: L10n.t("todayView.dcae5bdf"), value: String(format: L10n.t("todayView.e6541eb0"), summary.fingerTravelMeters))
                }
                if let persona = summary.persona {
                    BreakdownRow(label: L10n.t("todayView.7206e047"), value: "\(persona.keyboardAffinity)%")
                }
                if summary.typingConsistency > 0 {
                    BreakdownRow(label: L10n.t("todayView.99bb387e"), value: "\(summary.typingConsistency)%")
                }
                if let hour = summary.goldenHour {
                    BreakdownRow(label: L10n.t("todayView.34fdf6d2"), value: String(format: "%@ (%.0f WPM)", Formatters.hourLabel(hour), summary.goldenHourWPM))
                }
                if summary.distinctShortcutsUsed > 0 {
                    BreakdownRow(label: L10n.t("todayView.7efd4acf"), value: L10n.t("todayView.59f07901", summary.distinctShortcutsUsed))
                }
            }

            BreakdownCard(
                title: L10n.t("todayView.e53bb75b"),
                icon: "cursorarrow.click",
                headline: Formatters.groupedNumber(summary.totalClicks)
            ) {
                BreakdownRow(label: L10n.t("todayView.71bb002c"), value: Formatters.groupedNumber(summary.leftClicks))
                BreakdownRow(label: L10n.t("todayView.bef8caad"), value: Formatters.groupedNumber(summary.rightClicks))
                BreakdownRow(label: L10n.t("todayView.991f1b13"), value: Formatters.groupedNumber(summary.doubleClicks))
                BreakdownRow(label: L10n.t("todayView.ff52db1b"), value: Formatters.groupedNumber(summary.dragCount))
                if summary.dragDistanceMeters >= 1 {
                    BreakdownRow(label: L10n.t("todayView.b446b41f"), value: String(format: L10n.t("todayView.e6541eb0"), summary.dragDistanceMeters))
                }
                if summary.doubleClickRatio > 0 {
                    BreakdownRow(label: L10n.t("todayView.efe8fbe8"), value: String(format: "%.0f%%", summary.doubleClickRatio * 100))
                }
                BreakdownRow(label: L10n.t("todayView.c753318c"), value: "\(summary.maxClicksPerMinute)")
                Divider().padding(.vertical, 2)
                BreakdownRow(label: L10n.t("todayView.314017fc"), value: String(format: L10n.t("todayView.fafa7c2e"), summary.cursorDistanceMeters / 1000))
                BreakdownRow(label: L10n.t("todayView.30212b03"), value: String(format: L10n.t("todayView.6afaa89a"), summary.scrollScreens))
                BreakdownRow(label: L10n.t("todayView.f6262cbb"), value: String(format: "%.0f / %.0f pt", summary.scrollUpPoints, summary.scrollDownPoints))
                BreakdownRow(label: L10n.t("todayView.8bdb5ceb"), value: Formatters.groupedNumber(summary.scrollDirectionChanges))
            }

            BreakdownCard(
                title: L10n.t("todayView.c1569865"),
                icon: "square.stack.3d.up",
                headline: summary.topApp?.appName ?? "-"
            ) {
                BreakdownRow(label: L10n.t("todayView.f77d9ebb"), value: Formatters.groupedNumber(summary.totalAppSwitches))
                BreakdownRow(label: L10n.t("todayView.e5e0442d"), value: Formatters.compactDuration(Int(summary.avgAppDwellSeconds)))
                BreakdownRow(label: L10n.t("todayView.b1ae9ae3"), value: Formatters.groupedNumber(summary.shortDwellCount))
                BreakdownRow(label: L10n.t("todayView.9aef2c73"), value: "\(summary.focusSessionCount)")
                BreakdownRow(label: L10n.t("todayView.3eff78d8"), value: Formatters.compactDuration(summary.totalFocusSeconds))
                if let hour = summary.bestFocusHour {
                    BreakdownRow(label: L10n.t("todayView.55bde4f5"), value: Formatters.hourLabel(hour))
                }
                if let interrupter = summary.topInterruptingApp {
                    BreakdownRow(label: L10n.t("todayView.089588de"), value: interrupter)
                }
                if !summary.appUsage.isEmpty {
                    Divider().padding(.vertical, 2)
                    let top = Array(summary.appUsage.prefix(5))
                    let maxSeconds = top.first?.totalSeconds ?? 0
                    ForEach(top) { app in
                        AppUsageBar(appName: app.appName, seconds: app.totalSeconds, maxSeconds: maxSeconds)
                    }
                }
            }

            BreakdownCard(
                title: L10n.t("todayView.ccae3101"),
                icon: "clock",
                headline: Formatters.compactDuration(summary.activeSeconds)
            ) {
                if let first = summary.firstActivity {
                    BreakdownRow(label: L10n.t("todayView.24e8d287"), value: Formatters.time(first))
                }
                if let last = summary.lastActivity {
                    BreakdownRow(label: L10n.t("todayView.42ce99e0"), value: Formatters.time(last))
                }
                BreakdownRow(label: L10n.t("todayView.e5e7450c"), value: Formatters.compactDuration(summary.screenOnSeconds))
                if summary.screenOnSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.82962f06"), value: Formatters.compactDuration(summary.screenIdleSeconds))
                    BreakdownRow(label: L10n.t("todayView.a4db1d38"), value: "\(summary.screenUtilizationPercent)%")
                }
                BreakdownRow(label: L10n.t("todayView.4e954746"), value: Formatters.compactDuration(summary.idleSeconds))
                if summary.longestBreakSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.5c9dc383"), value: Formatters.compactDuration(summary.longestBreakSeconds))
                }
                BreakdownRow(label: L10n.t("todayView.198b4500"), value: "\(summary.activitySessionCount)")
                BreakdownRow(label: L10n.t("todayView.a1249b1f"), value: Formatters.compactDuration(Int(summary.avgSessionSeconds)))
                Divider().padding(.vertical, 2)
                BreakdownRow(label: L10n.t("todayView.474fe719"), value: "\(summary.sleepCount) / \(summary.wakeCount)")
                if summary.totalSleepSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.d628cf08"), value: Formatters.compactDuration(summary.totalSleepSeconds))
                    BreakdownRow(label: L10n.t("todayView.0c314faf"), value: Formatters.compactDuration(summary.longestSleepSeconds))
                }
                BreakdownRow(label: L10n.t("todayView.317076ea"), value: "\(summary.lockCount) / \(summary.unlockCount)")
                BreakdownRow(label: L10n.t("todayView.e742f8c0"), value: L10n.t("todayView.cf3d71b3", summary.displaySleepCount))
            }

            BreakdownCard(
                title: L10n.t("todayView.1a66f4e1"),
                icon: "battery.100.bolt",
                headline: summary.currentBatteryLevel.map { "\($0)%" } ?? "-"
            ) {
                if let min = summary.minBatteryLevel, let max = summary.maxBatteryLevel {
                    BreakdownRow(label: L10n.t("todayView.9958eb00"), value: "\(min)% / \(max)%")
                }
                if summary.batteryDrainedPercent > 0 {
                    BreakdownRow(label: L10n.t("todayView.81bdc1fb"), value: "\(summary.batteryDrainedPercent)%")
                }
                BreakdownRow(label: L10n.t("todayView.f6fe026e"), value: "\(summary.chargerConnectCount) / \(summary.chargerDisconnectCount)")
                if summary.chargeSessionCount > 0 {
                    BreakdownRow(label: L10n.t("todayView.791dc165"), value: L10n.t("todayView.cf3d71b3", summary.chargeSessionCount))
                    BreakdownRow(label: L10n.t("todayView.1ba5cbbf"), value: "+\(summary.totalChargedPercent)%")
                }
                BreakdownRow(label: L10n.t("todayView.4cbcb836"), value: Formatters.compactDuration(summary.secondsOnBattery))
                BreakdownRow(label: L10n.t("todayView.bbb312c1"), value: Formatters.compactDuration(summary.secondsOnAC))
                if summary.lowPowerModeSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.6225d89a"), value: Formatters.compactDuration(summary.lowPowerModeSeconds))
                }
                if summary.elevatedThermalSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.ebc270ac"), value: Formatters.compactDuration(summary.elevatedThermalSeconds))
                }
                if let wh = BatteryHardware.shared.fullChargeWattHours {
                    Divider().padding(.vertical, 2)
                    BreakdownRow(label: L10n.t("todayView.bb770076"), value: String(format: "%.1fWh", wh))
                }
                if let cycles = summary.batteryCycleCount {
                    BreakdownRow(label: L10n.t("todayView.d3f1a005"), value: L10n.t("todayView.cf3d71b3", cycles))
                }
                if let health = summary.batteryHealthPercent {
                    BreakdownRow(label: L10n.t("todayView.dd60e8af"), value: "\(health)%")
                }
                if summary.batteryTimeline.count >= 2 {
                    BatteryTimelineView(
                        samples: summary.batteryTimeline,
                        minLevel: summary.minBatteryLevel,
                        maxLevel: summary.maxBatteryLevel
                    )
                    .padding(.top, 4)
                }
            }

            BreakdownCard(
                title: L10n.t("todayView.010910ad"),
                icon: "laptopcomputer.and.arrow.down",
                headline: summary.lidCloseCount > 0 ? L10n.t("todayView.0963ab49", summary.lidCloseCount) : "-"
            ) {
                BreakdownRow(label: L10n.t("todayView.4905bfcf"), value: "\(summary.lidCloseCount) / \(summary.lidOpenCount)")
                if summary.lidClosedSeconds > 0 {
                    BreakdownRow(label: L10n.t("todayView.13322d1a"), value: Formatters.compactDuration(summary.lidClosedSeconds))
                }
                Text(L10n.t("todayView.52d7858e"))
                    .font(.caption2).foregroundStyle(.tertiary)
                Divider().padding(.vertical, 2)
                BreakdownRow(label: L10n.t("todayView.a829f60b"), value: "\(summary.externalDisplayConnectCount) / \(summary.externalDisplayDisconnectCount)")
                BreakdownRow(label: L10n.t("todayView.1853f54e"), value: L10n.t("todayView.817fc9a0", summary.maxSimultaneousDisplays))
                BreakdownRow(label: L10n.t("todayView.e4d2449e"), value: L10n.t("todayView.cf3d71b3", summary.audioOutputDeviceChangeCount))
            }

            if summary.networkTotalBytes > 0 {
                BreakdownCard(
                    title: L10n.t("todayView.5fcc05cf"),
                    icon: "network",
                    headline: Formatters.bytes(summary.networkTotalBytes),
                    explanation: MetricExplanations.network.body,
                    explanationDetail: MetricExplanations.network.detail
                ) {
                    BreakdownRow(label: L10n.t("todayView.5c5095ab"), value: Formatters.bytes(summary.networkDownloadBytes))
                    BreakdownRow(label: L10n.t("todayView.51672ccd"), value: Formatters.bytes(summary.networkUploadBytes))
                    if summary.peakDownloadBytesPerSec > 0 {
                        BreakdownRow(label: L10n.t("todayView.6bbd0fd4"), value: Formatters.bytesPerSecond(summary.peakDownloadBytesPerSec))
                    }
                    if summary.peakUploadBytesPerSec > 0 {
                        BreakdownRow(label: L10n.t("todayView.201aa265"), value: Formatters.bytesPerSecond(summary.peakUploadBytesPerSec))
                    }
                }
            }

            if !summary.clipboardTypeCounts.isEmpty || summary.clipboardCopyCount > 0 {
                BreakdownCard(
                    title: L10n.t("todayView.9ace854b"),
                    icon: "doc.on.clipboard",
                    headline: "\(summary.clipboardCopyCount) / \(summary.clipboardPasteCount)"
                ) {
                    BreakdownRow(label: L10n.t("todayView.a55b1ecb"), value: Formatters.groupedNumber(summary.clipboardCopyCount))
                    BreakdownRow(label: L10n.t("todayView.245c1c44"), value: Formatters.groupedNumber(summary.clipboardPasteCount))
                    BreakdownRow(label: L10n.t("todayView.799f28ec"), value: Formatters.groupedNumber(summary.clipboardCutCount))
                    if !summary.clipboardTypeCounts.isEmpty {
                        Divider().padding(.vertical, 2)
                        ForEach(ClipboardDataType.allCases, id: \.self) { type in
                            if let count = summary.clipboardTypeCounts[type], count > 0 {
                                BreakdownRow(label: type.displayName, value: Formatters.groupedNumber(count))
                            }
                        }
                    }
                    Text(L10n.t("todayView.260c07c2"))
                        .font(.caption2).foregroundStyle(.tertiary).padding(.top, 2)
                }
            }
        }
    }
}
