import SwiftUI

@MainActor
struct TodayView: View {
    @Bindable var activityCenter = ActivityCenter.shared

    /// Where the fun-fact window starts. Randomized per launch and advanced on a timer.
    @State private var factOffset = Int.random(in: 0..<1000)
    /// Rotated slowly — the facts are meant to be read, not to flicker past.
    private let factTimer = Timer.publish(every: 45, on: .main, in: .common).autoconnect()

    private var summary: DailySummary { activityCenter.todaySummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let broken = RecordTracker.shared.pendingCelebration {
                RecordBrokenBanner(standing: broken) { RecordTracker.shared.clearCelebration() }
            }

            if let score = summary.score {
                ScoreCard(score: score, persona: summary.persona)
            }

            ShareButton(
                mode: .today(summary),
                label: L10n.t("todayView.9f2ea5d8"),
                suggestedFileName: "pawprint_\(summary.day).png"
            )

            if !activityCenter.todayPercentiles.isEmpty {
                PercentileCard(
                    rankings: activityCenter.todayPercentiles,
                    headline: activityCenter.headlinePercentile
                )
            }

            cardGrid

            Text(summary.summarySentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))

            if !summary.activityTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(summary.activityTags, id: \.self) { tag in
                        Text("\(tag.emoji) \(tag.label)")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }

            ActivityClockView(
                activityPerMinute: summary.activityPerMinute,
                dayStartHour: activityCenter.settings.dayStartHour
            )

            if !comparisons.isEmpty {
                ComparisonCard(comparisons: comparisons)
            }

            recordChaseSection

            MiniTimelineView(activityPerMinute: summary.activityPerMinute)

            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("todayView.8a44ca6e")).font(.caption).foregroundStyle(.secondary)
                    ForEach(summary.highlights) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                }
            }

            funFactsSection
                .id(PopoverRootView.funFactsAnchor)

            if !summary.energyFacts.isEmpty {
                EnergyCard(lines: summary.energyFacts.map(\.text), drainedPercent: summary.batteryDrainedPercent)
            }

            indicesRow

            PawpetCard(summary: summary, streakDays: activityCenter.currentStreak)

            KeyboardHeatmapView(summary: summary)

            if !summary.appInputProfiles.isEmpty {
                AppInputCard(profiles: summary.appInputProfiles)
            }

            breakdowns
        }
        .padding(14)
    }

    /// "How close am I to my own record" — surfaced while the day is still in progress, since a
    /// near-miss you can still act on is more interesting than one reported after midnight.
    private var recordChaseSection: some View {
        let standings = RecordTracker.shared.standings.prefix(3)
        return Group {
            if !standings.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        Label(L10n.t("todayView.8605982f"), systemImage: "flag.checkered")
                            .font(.caption).foregroundStyle(.secondary)
                        InfoBadge(
                            title: L10n.t("todayView.8605982f"),
                            explanation: L10n.t("todayView.9234fafa"),
                            detail: L10n.t("todayView.ba83ad47")
                        )
                        Spacer()
                    }
                    ForEach(Array(standings)) { standing in
                        RecordChaseRow(standing: standing)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
            }
        }
    }

    /// Facts cycle on their own so the card keeps offering something new, plus a shuffle button
    /// for anyone who wants to keep pulling.
    private var funFactsSection: some View {
        Group {
            if !summary.funFacts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(L10n.t("todayView.f04f7e9b")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { factOffset += 1 }
                        } label: {
                            Image(systemName: "shuffle").font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.t("todayView.00005fd3"))
                    }
                    ForEach(pickedFunFacts) { fact in
                        HStack(alignment: .top, spacing: 6) {
                            Text("✨").font(.caption)
                            Text(fact.text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    }
                    Text(L10n.t("todayView.d066a442"))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.3)))
                .onReceive(factTimer) { _ in
                    withAnimation(.easeInOut(duration: 0.4)) { factOffset += 1 }
                }
            }
        }
    }

    /// Five facts, each about a *different* quantity. The conversion engine deliberately produces
    /// many analogies per quantity, so picking blindly would show five ways of saying the same
    /// thing. Topics are walked in a rotating order and one line is taken from each.
    private var pickedFunFacts: [FunFact] {
        let facts = summary.funFacts
        guard facts.count > 5 else { return facts }

        var byTopic: [FunFact.Topic: [FunFact]] = [:]
        for fact in facts { byTopic[fact.topic, default: []].append(fact) }
        let topics = FunFact.Topic.allCases.filter { byTopic[$0] != nil }
        guard !topics.isEmpty else { return Array(facts.prefix(5)) }

        var picked: [FunFact] = []
        for step in 0..<topics.count where picked.count < 5 {
            let topic = topics[(factOffset + step) % topics.count]
            guard let pool = byTopic[topic], !pool.isEmpty else { continue }
            picked.append(pool[factOffset % pool.count])
        }
        // If there were fewer than five distinct topics, top up with whatever is left.
        if picked.count < 5 {
            for fact in facts where picked.count < 5 && !picked.contains(fact) {
                picked.append(fact)
            }
        }
        return picked
    }

    /// Compares a few headline metrics against the recent average.
    private var comparisons: [MetricComparison] {
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

    private var breakdowns: some View {
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

    private var header: some View {
        let mood = MascotMood.current(activityCenter: activityCenter)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.dayLabel(summary.day))
                    .font(.headline)
                RecordingStatusLabel()
            }
            Spacer()
            HStack(spacing: 6) {
                if activityCenter.liveWPM >= 1 {
                    Text(String(format: "%.0f WPM", activityCenter.liveWPM))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .transition(.opacity)
                }
                Text(mood.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                MascotView(mood: mood, size: 32)
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(activityCenter.settings.dashboardCardIDs, id: \.self) { id in
                if let metric = MetricCatalog.metric(id: id) {
                    StatCard(metric: metric, summary: summary)
                }
            }
        }
    }

    private var indicesRow: some View {
        HStack(spacing: 8) {
            IndexBadge(
                title: MetricExplanations.regret.title,
                value: summary.regretIndex,
                color: .orange,
                explanation: MetricExplanations.regret.body,
                detail: MetricExplanations.regret.detail
            )
            IndexBadge(
                title: MetricExplanations.chaos.title,
                value: summary.chaosIndex,
                color: .purple,
                explanation: MetricExplanations.chaos.body,
                detail: MetricExplanations.chaos.detail
            )
        }
    }
}

@MainActor
private struct RecordingStatusLabel: View {
    @Bindable var activityCenter = ActivityCenter.shared

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(activityCenter.isRecordingActive ? .green : .secondary)
                .frame(width: 6, height: 6)
            Text(activityCenter.isRecordingActive ? L10n.t("todayView.20f5a114") : (activityCenter.settings.isPaused ? L10n.t("todayView.2c992a87") : L10n.t("todayView.69b3a3dc")))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
private struct HighlightRow: View {
    let highlight: Highlight

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: highlight.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.title).font(.caption.weight(.semibold))
                Text(highlight.detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
private struct IndexBadge: View {
    let title: String
    let value: Double
    let color: Color
    var explanation: String? = nil
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                if let explanation {
                    InfoBadge(title: title, explanation: explanation, detail: detail)
                }
            }
            HStack {
                ProgressView(value: min(value, 100), total: 100)
                    .tint(color)
                Text("\(Int(value))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.4)))
    }
}
