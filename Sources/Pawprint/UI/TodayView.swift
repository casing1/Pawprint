import SwiftUI

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
                label: "오늘 카드",
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
                    Text("오늘의 하이라이트").font(.caption).foregroundStyle(.secondary)
                    ForEach(summary.highlights) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                }
            }

            funFactsSection

            if !summary.energyFacts.isEmpty {
                EnergyCard(lines: summary.energyFacts.map(\.text), drainedPercent: summary.batteryDrainedPercent)
            }

            indicesRow

            PawpetCard(
                summary: summary,
                streakDays: activityCenter.currentStreak,
                isCelebrating: RecordTracker.shared.pendingCelebration != nil
                    || activityCenter.pendingLevelUp != nil
            )

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
                        Label("개인 기록 추격", systemImage: "flag.checkered")
                            .font(.caption).foregroundStyle(.secondary)
                        InfoBadge(
                            title: "개인 기록 추격",
                            explanation: "오늘 값이 지금까지의 개인 최고 기록에 얼마나 근접했는지 보여줘요.",
                            detail: "비교 대상은 오늘을 제외한 과거 기록이에요."
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
                        Text("오늘의 재미있는 사실").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(summary.funFacts.count)개 중 5개")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { factOffset += 1 }
                        } label: {
                            Image(systemName: "shuffle").font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .help("다른 사실 보기")
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
                    Text("환산값은 모두 근사치예요")
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
            label: "키 입력",
            todayValue: keysToday,
            averageValue: average { Double($0.totalKeyPresses) },
            display: Formatters.groupedNumber(summary.totalKeyPresses),
            isRecord: isRecord({ Double($0.totalKeyPresses) }, today: keysToday)
        ))

        let activeToday = Double(summary.activeSeconds)
        result.append(MetricComparison(
            label: "활성 사용시간",
            todayValue: activeToday,
            averageValue: average { Double($0.activeSeconds) },
            display: Formatters.compactDuration(summary.activeSeconds),
            isRecord: isRecord({ Double($0.activeSeconds) }, today: activeToday)
        ))

        let focusToday = Double(summary.totalFocusSeconds)
        result.append(MetricComparison(
            label: "집중시간",
            todayValue: focusToday,
            averageValue: average { Double($0.totalFocusSeconds) },
            display: Formatters.compactDuration(summary.totalFocusSeconds),
            isRecord: isRecord({ Double($0.totalFocusSeconds) }, today: focusToday)
        ))

        if summary.maxWPM > 0 {
            result.append(MetricComparison(
                label: "최고 타자 속도",
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
            Text("자세히 보기").font(.caption).foregroundStyle(.secondary)

            BreakdownCard(
                title: "키보드",
                icon: "keyboard",
                headline: Formatters.groupedNumber(summary.totalKeyPresses)
            ) {
                BreakdownRow(label: "문자 키", value: Formatters.groupedNumber(summary.characterKeyPresses))
                BreakdownRow(label: "평균 타자 속도", value: summary.avgWPM > 0 ? Formatters.wpm(summary.avgWPM) : "-")
                BreakdownRow(label: "Backspace", value: Formatters.groupedNumber(summary.keyCategoryCounts[.backspace] ?? 0))
                BreakdownRow(label: "입력 대비 Backspace 비율", value: String(format: "%.1f%%", summary.backspaceRatio * 100))
                BreakdownRow(label: "Escape", value: Formatters.groupedNumber(summary.keyCategoryCounts[.escape] ?? 0))
                BreakdownRow(label: "Space", value: Formatters.groupedNumber(summary.keyCategoryCounts[.space] ?? 0))
                BreakdownRow(label: "Enter", value: Formatters.groupedNumber(summary.keyCategoryCounts[.enter] ?? 0))
                BreakdownRow(label: "방향키", value: Formatters.groupedNumber(summary.keyCategoryCounts[.arrow] ?? 0))
                BreakdownRow(label: "한영 전환", value: Formatters.groupedNumber(summary.keyCategoryCounts[.hangulSwitch] ?? 0))
                Divider().padding(.vertical, 2)
                BreakdownRow(label: "복사 / 붙여넣기", value: "\(summary.shortcutCounts[.copy] ?? 0) / \(summary.shortcutCounts[.paste] ?? 0)")
                BreakdownRow(label: "잘라내기", value: Formatters.groupedNumber(summary.shortcutCounts[.cut] ?? 0))
                BreakdownRow(label: "Undo / Redo", value: "\(summary.shortcutCounts[.undo] ?? 0) / \(summary.shortcutCounts[.redo] ?? 0)")
                BreakdownRow(label: "전체 선택", value: Formatters.groupedNumber(summary.shortcutCounts[.selectAll] ?? 0))
                BreakdownRow(label: "Spotlight", value: Formatters.groupedNumber(summary.shortcutCounts[.spotlight] ?? 0))
                BreakdownRow(label: "스크린샷", value: Formatters.groupedNumber(summary.shortcutCounts[.screenshot] ?? 0))
                BreakdownRow(label: "Cmd+Tab 앱 전환", value: Formatters.groupedNumber(summary.shortcutCounts[.appSwitch] ?? 0))
                BreakdownRow(label: "최장 연속 타이핑", value: Formatters.compactDuration(summary.longestTypingStreakSeconds))
                BreakdownRow(label: "타이핑 세션 수", value: "\(summary.typingSessionCount)")
                if summary.fingerTravelMeters >= 1 {
                    BreakdownRow(label: "손가락 이동 거리", value: String(format: "약 %.0fm", summary.fingerTravelMeters))
                }
                if let persona = summary.persona {
                    BreakdownRow(label: "키보드 의존도", value: "\(persona.keyboardAffinity)%")
                }
                if summary.typingConsistency > 0 {
                    BreakdownRow(label: "타이핑 일관성", value: "\(summary.typingConsistency)%")
                }
                if let hour = summary.goldenHour {
                    BreakdownRow(label: "황금 시간대", value: String(format: "%@ (%.0f WPM)", Formatters.hourLabel(hour), summary.goldenHourWPM))
                }
                if summary.distinctShortcutsUsed > 0 {
                    BreakdownRow(label: "사용한 단축키 종류", value: "\(summary.distinctShortcutsUsed)종")
                }
            }

            BreakdownCard(
                title: "마우스 / 트랙패드",
                icon: "cursorarrow.click",
                headline: Formatters.groupedNumber(summary.totalClicks)
            ) {
                BreakdownRow(label: "왼쪽 클릭", value: Formatters.groupedNumber(summary.leftClicks))
                BreakdownRow(label: "오른쪽 클릭", value: Formatters.groupedNumber(summary.rightClicks))
                BreakdownRow(label: "더블클릭", value: Formatters.groupedNumber(summary.doubleClicks))
                BreakdownRow(label: "드래그", value: Formatters.groupedNumber(summary.dragCount))
                if summary.dragDistanceMeters >= 1 {
                    BreakdownRow(label: "드래그 거리", value: String(format: "약 %.0fm", summary.dragDistanceMeters))
                }
                if summary.doubleClickRatio > 0 {
                    BreakdownRow(label: "더블클릭 비율", value: String(format: "%.0f%%", summary.doubleClickRatio * 100))
                }
                BreakdownRow(label: "분당 최고 클릭", value: "\(summary.maxClicksPerMinute)")
                Divider().padding(.vertical, 2)
                BreakdownRow(label: "커서 이동 거리", value: String(format: "약 %.2fkm", summary.cursorDistanceMeters / 1000))
                BreakdownRow(label: "스크롤 (화면 높이 기준)", value: String(format: "약 %.1f화면", summary.scrollScreens))
                BreakdownRow(label: "위 / 아래 스크롤", value: String(format: "%.0f / %.0f pt", summary.scrollUpPoints, summary.scrollDownPoints))
                BreakdownRow(label: "스크롤 방향 전환", value: Formatters.groupedNumber(summary.scrollDirectionChanges))
            }

            BreakdownCard(
                title: "앱과 집중",
                icon: "square.stack.3d.up",
                headline: summary.topApp?.appName ?? "-"
            ) {
                BreakdownRow(label: "앱 전환 횟수", value: Formatters.groupedNumber(summary.totalAppSwitches))
                BreakdownRow(label: "평균 체류시간", value: Formatters.compactDuration(Int(summary.avgAppDwellSeconds)))
                BreakdownRow(label: "5초 미만 체류", value: Formatters.groupedNumber(summary.shortDwellCount))
                BreakdownRow(label: "집중 세션 수", value: "\(summary.focusSessionCount)")
                BreakdownRow(label: "전체 집중시간", value: Formatters.compactDuration(summary.totalFocusSeconds))
                if let hour = summary.bestFocusHour {
                    BreakdownRow(label: "집중이 잘된 시간대", value: Formatters.hourLabel(hour))
                }
                if let interrupter = summary.topInterruptingApp {
                    BreakdownRow(label: "집중을 자주 끊은 앱", value: interrupter)
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
                title: "시간과 Mac 상태",
                icon: "clock",
                headline: Formatters.compactDuration(summary.activeSeconds)
            ) {
                if let first = summary.firstActivity {
                    BreakdownRow(label: "첫 활동", value: Formatters.time(first))
                }
                if let last = summary.lastActivity {
                    BreakdownRow(label: "마지막 활동", value: Formatters.time(last))
                }
                BreakdownRow(label: "화면 켜짐 시간", value: Formatters.compactDuration(summary.screenOnSeconds))
                if summary.screenOnSeconds > 0 {
                    BreakdownRow(label: "화면 켜두고 안 쓴 시간", value: Formatters.compactDuration(summary.screenIdleSeconds))
                    BreakdownRow(label: "화면 활용도", value: "\(summary.screenUtilizationPercent)%")
                }
                BreakdownRow(label: "유휴시간", value: Formatters.compactDuration(summary.idleSeconds))
                if summary.longestBreakSeconds > 0 {
                    BreakdownRow(label: "가장 긴 휴식", value: Formatters.compactDuration(summary.longestBreakSeconds))
                }
                BreakdownRow(label: "활동 세션 수", value: "\(summary.activitySessionCount)")
                BreakdownRow(label: "평균 세션 길이", value: Formatters.compactDuration(Int(summary.avgSessionSeconds)))
                Divider().padding(.vertical, 2)
                BreakdownRow(label: "잠자기 / 깨우기", value: "\(summary.sleepCount) / \(summary.wakeCount)")
                if summary.totalSleepSeconds > 0 {
                    BreakdownRow(label: "잠들어 있던 시간", value: Formatters.compactDuration(summary.totalSleepSeconds))
                    BreakdownRow(label: "가장 긴 잠자기", value: Formatters.compactDuration(summary.longestSleepSeconds))
                }
                BreakdownRow(label: "화면 잠금 / 해제", value: "\(summary.lockCount) / \(summary.unlockCount)")
                BreakdownRow(label: "화면 꺼짐", value: "\(summary.displaySleepCount)회")
            }

            BreakdownCard(
                title: "배터리와 전원",
                icon: "battery.100.bolt",
                headline: summary.currentBatteryLevel.map { "\($0)%" } ?? "-"
            ) {
                if let min = summary.minBatteryLevel, let max = summary.maxBatteryLevel {
                    BreakdownRow(label: "최저 / 최고 배터리", value: "\(min)% / \(max)%")
                }
                if summary.batteryDrainedPercent > 0 {
                    BreakdownRow(label: "사용한 배터리", value: "\(summary.batteryDrainedPercent)%")
                }
                BreakdownRow(label: "충전기 연결 / 분리", value: "\(summary.chargerConnectCount) / \(summary.chargerDisconnectCount)")
                if summary.chargeSessionCount > 0 {
                    BreakdownRow(label: "충전 세션", value: "\(summary.chargeSessionCount)회")
                    BreakdownRow(label: "충전한 총량", value: "+\(summary.totalChargedPercent)%")
                }
                BreakdownRow(label: "배터리 사용시간", value: Formatters.compactDuration(summary.secondsOnBattery))
                BreakdownRow(label: "외부 전원 사용시간", value: Formatters.compactDuration(summary.secondsOnAC))
                if summary.lowPowerModeSeconds > 0 {
                    BreakdownRow(label: "저전력 모드", value: Formatters.compactDuration(summary.lowPowerModeSeconds))
                }
                if summary.elevatedThermalSeconds > 0 {
                    BreakdownRow(label: "발열 상승 상태", value: Formatters.compactDuration(summary.elevatedThermalSeconds))
                }
                if let wh = BatteryHardware.shared.fullChargeWattHours {
                    Divider().padding(.vertical, 2)
                    BreakdownRow(label: "배터리 총 용량", value: String(format: "%.1fWh", wh))
                }
                if let cycles = summary.batteryCycleCount {
                    BreakdownRow(label: "충전 사이클", value: "\(cycles)회")
                }
                if let health = summary.batteryHealthPercent {
                    BreakdownRow(label: "배터리 건강도", value: "\(health)%")
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
                title: "뚜껑과 장치",
                icon: "laptopcomputer.and.arrow.down",
                headline: summary.lidCloseCount > 0 ? "\(summary.lidCloseCount)번 닫음" : "-"
            ) {
                BreakdownRow(label: "뚜껑 닫음 / 열음", value: "\(summary.lidCloseCount) / \(summary.lidOpenCount)")
                if summary.lidClosedSeconds > 0 {
                    BreakdownRow(label: "닫혀 있던 시간", value: Formatters.compactDuration(summary.lidClosedSeconds))
                }
                Text("뚜껑을 닫아도 Mac이 깨어 있는 경우(외장 모니터 연결 등)만 집계돼요.")
                    .font(.caption2).foregroundStyle(.tertiary)
                Divider().padding(.vertical, 2)
                BreakdownRow(label: "외장 디스플레이 연결 / 해제", value: "\(summary.externalDisplayConnectCount) / \(summary.externalDisplayDisconnectCount)")
                BreakdownRow(label: "최대 동시 디스플레이", value: "\(summary.maxSimultaneousDisplays)개")
                BreakdownRow(label: "오디오 출력 변경", value: "\(summary.audioOutputDeviceChangeCount)회")
            }

            if summary.networkTotalBytes > 0 {
                BreakdownCard(
                    title: "네트워크",
                    icon: "network",
                    headline: Formatters.bytes(summary.networkTotalBytes),
                    explanation: MetricExplanations.network.body,
                    explanationDetail: MetricExplanations.network.detail
                ) {
                    BreakdownRow(label: "다운로드", value: Formatters.bytes(summary.networkDownloadBytes))
                    BreakdownRow(label: "업로드", value: Formatters.bytes(summary.networkUploadBytes))
                    if summary.peakDownloadBytesPerSec > 0 {
                        BreakdownRow(label: "최고 다운로드 속도", value: Formatters.bytesPerSecond(summary.peakDownloadBytesPerSec))
                    }
                    if summary.peakUploadBytesPerSec > 0 {
                        BreakdownRow(label: "최고 업로드 속도", value: Formatters.bytesPerSecond(summary.peakUploadBytesPerSec))
                    }
                }
            }

            if !summary.clipboardTypeCounts.isEmpty || summary.clipboardCopyCount > 0 {
                BreakdownCard(
                    title: "클립보드",
                    icon: "doc.on.clipboard",
                    headline: "\(summary.clipboardCopyCount) / \(summary.clipboardPasteCount)"
                ) {
                    BreakdownRow(label: "복사", value: Formatters.groupedNumber(summary.clipboardCopyCount))
                    BreakdownRow(label: "붙여넣기", value: Formatters.groupedNumber(summary.clipboardPasteCount))
                    BreakdownRow(label: "잘라내기", value: Formatters.groupedNumber(summary.clipboardCutCount))
                    if !summary.clipboardTypeCounts.isEmpty {
                        Divider().padding(.vertical, 2)
                        ForEach(ClipboardDataType.allCases, id: \.self) { type in
                            if let count = summary.clipboardTypeCounts[type], count > 0 {
                                BreakdownRow(label: type.displayName, value: Formatters.groupedNumber(count))
                            }
                        }
                    }
                    Text("내용은 저장하지 않고 유형만 분류합니다.")
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

private struct RecordingStatusLabel: View {
    @Bindable var activityCenter = ActivityCenter.shared

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(activityCenter.isRecordingActive ? .green : .secondary)
                .frame(width: 6, height: 6)
            Text(activityCenter.isRecordingActive ? "기록 중" : (activityCenter.settings.isPaused ? "일시정지됨" : "이 앱은 제외됨"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

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
