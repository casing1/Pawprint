import AppKit
import SwiftUI

/// Debug-only helpers, all gated behind environment variables so they never run in normal use.
/// They exist because this app has no testable UI surface from the command line — rendering the
/// popover to PNGs and dumping window state is the only way to catch layout and focus regressions.
enum DebugSnapshot {

    // MARK: - Settings/window state probe (PAWPRINT_PROBE)

    @MainActor
    static func probeSettings() {
        log("BEFORE")
        let respondsSettings = NSApp.responds(to: Selector(("showSettingsWindow:")))
        let respondsPrefs = NSApp.responds(to: Selector(("showPreferencesWindow:")))
        write("respondsShowSettings=\(respondsSettings) respondsShowPreferences=\(respondsPrefs)\n")

        SettingsOpener.open()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            log("AFTER OPEN")
            NSApp.windows.first { $0.title == "Pawprint 설정" }?.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                log("AFTER CLOSE")
                exit(0)
            }
        }
    }

    @MainActor
    private static func log(_ label: String) {
        var out = "\n[\(label)] policy=\(NSApp.activationPolicy().rawValue) active=\(NSApp.isActive) windowCount=\(NSApp.windows.count)\n"
        for window in NSApp.windows {
            out += "   - \(type(of: window)) title=\"\(window.title)\""
            out += " visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow)"
            out += " level=\(window.level.rawValue) canBecomeKey=\(window.canBecomeKey)\n"
        }
        write(out)
    }

    private static func write(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    // MARK: - Title & persona spread (PAWPRINT_TITLES)

    /// Prints every rank/title the progression can produce, and runs a batch of randomised days
    /// through `DailyPersona` to confirm the label actually varies instead of collapsing onto one.
    @MainActor
    static func runTitleReport() {
        var out = "QUEST TITLES (levels 0-20)\n"
        for track in QuestTrack.allCases {
            var line = "  \(track.title): "
            for level in [0, 1, 2, 4, 6, 8, 10, 12, 14, 17, 22] {
                let q = QuestProgress(track: track, level: level, currentValue: 0, levelStart: 0, levelTarget: 1)
                line += "\(level)=\(q.displayTitle)  "
            }
            out += line + "\n"
        }
        out += "\nRANKS (\(QuestProgress.rankCount)): "
            + QuestProgress.ranks.map(\.name).joined(separator: " → ") + "\n"
        out += "OVERALL TITLES (\(OverallLevel.titles.count + 1)): "
            + (OverallLevel.titles.map(\.name) + ["발자국 그 자체"]).joined(separator: " → ") + "\n"

        var generator = SystemRandomNumberGenerator()
        var tally: [String: Int] = [:]
        for i in 0..<400 {
            let s = randomSummary(index: i, using: &generator)
            if let persona = DailyPersona.build(from: s) {
                tally[persona.emoji + " " + persona.title, default: 0] += 1
            }
        }
        out += "\nPERSONA SPREAD over 400 random days (\(tally.count) distinct):\n"
        for (name, count) in tally.sorted(by: { $0.value > $1.value }) {
            out += String(format: "   %4d  %@\n", count, name)
        }
        if let today = DailyPersona.build(from: ActivityCenter.shared.todaySummary) {
            out += "\nTODAY: \(today.emoji) \(today.title) — \(today.detail)\n"
        }
        write(out)
    }

    // MARK: - Update pipeline exercise (PAWPRINT_UPDATE_TEST)

    @MainActor
    static func runUpdateFlow(feed: String) {
        Task { @MainActor in
            let updater = UpdateChecker.shared
            write("UPDATE current=\(updater.currentVersion) (\(updater.currentBuild))\n")

            await updater.check(feedURL: feed, manual: true)
            write("UPDATE after check: \(updater.state)\n")
            guard case .available(let release) = updater.state else {
                write("UPDATE stopped — no update offered\n")
                exit(1)
            }

            await updater.download(release)
            write("UPDATE after download: \(updater.state)\n")
            guard case .readyToInstall = updater.state else {
                write("UPDATE stopped — download or verification failed\n")
                exit(2)
            }

            write("UPDATE installing (process will exit and relaunch)\n")
            updater.install()
        }
    }

    // MARK: - Best-combination showcase (PAWPRINT_SHOWCASE)

    /// Renders the *top-tier* cats: S-grade frames, every paw charm, every wing type.
    ///
    /// Reward traits split across two sources — the metrics decide *whether* you get a charm, the
    /// date decides *which* one — so a showcase can't just set fields. It searches day strings
    /// until the date-seeded draw lands on the target charm/wings, which also gives each cell a
    /// different coat for free.
    @MainActor
    static func renderShowcase() {
        struct Recipe {
            let title: String
            let charm: PawpetTraits.PawCharm
            let wings: PawpetTraits.Wings
            let celebrating: Bool
            let hour: Int
            let tune: (inout DailySummary) -> Void
        }

        func noop(_ s: inout DailySummary) {}

        let recipes: [Recipe] = [
            Recipe(title: "신기록의 날", charm: .orb, wings: .feathered, celebrating: true, hour: 14, tune: noop),
            Recipe(title: "레벨업의 날", charm: .star, wings: .crystal, celebrating: true, hour: 10, tune: noop),
            Recipe(title: "질주", charm: .flame, wings: .ember, celebrating: false, hour: 15) { $0.maxWPM = 130 },
            Recipe(title: "몰입", charm: .crystal, wings: .feathered, celebrating: false, hour: 9) { $0.longestFocusSeconds = 90 * 60 },
            Recipe(title: "왕관과 건틀릿", charm: .gauntlet, wings: .crystal, celebrating: false, hour: 20, tune: noop),
            Recipe(title: "고리의 주인", charm: .ring, wings: .ember, celebrating: false, hour: 7, tune: noop),
            Recipe(title: "빛깃털", charm: .feather, wings: .feathered, celebrating: false, hour: 22, tune: noop),
            Recipe(title: "새벽의 정점", charm: .orb, wings: .crystal, celebrating: false, hour: 3, tune: noop),
            Recipe(title: "여유로운 승리", charm: .star, wings: .ember, celebrating: false, hour: 17) { $0.longestBreakSeconds = 3 * 3600; $0.longestFocusSeconds = 20 * 60 },
            Recipe(title: "폭주 클릭", charm: .flame, wings: .feathered, celebrating: false, hour: 12) { $0.maxClicksPerMinute = 80; $0.longestFocusSeconds = 20 * 60 },
            Recipe(title: "앱 유랑", charm: .crystal, wings: .ember, celebrating: false, hour: 11) { $0.totalAppSwitches = 260; $0.longestFocusSeconds = 20 * 60 },
            Recipe(title: "혼돈 속의 S", charm: .gauntlet, wings: .feathered, celebrating: false, hour: 19) { $0.chaosIndex = 80 },
            Recipe(title: "안경 낀 대가", charm: .ring, wings: .crystal, celebrating: false, hour: 13) { $0.characterKeyPresses = 12_000 },
            Recipe(title: "음악과 함께", charm: .feather, wings: .ember, celebrating: false, hour: 16) { $0.audioOutputDeviceChangeCount = 4 },
            Recipe(title: "데이터 폭식", charm: .orb, wings: .ember, celebrating: false, hour: 21) { $0.networkTotalBytes = 12 * 1024 * 1024 * 1024 },
            Recipe(title: "고요한 승리", charm: .star, wings: .feathered, celebrating: false, hour: 6) { $0.longestBreakSeconds = 3 * 3600; $0.longestFocusSeconds = 20 * 60 }
        ]

        var used: Set<Int> = []
        var built: [(DailySummary, Bool, Recipe, PawpetTraits)] = []
        _ = 0

        for recipe in recipes {
            var chosen: (DailySummary, PawpetTraits)?
            var fallback: (DailySummary, PawpetTraits)?
            // Walk the calendar until the date-seeded draw yields this charm/wings pair, and
            // prefer a date whose palette hasn't been shown yet.
            outer: for month in 1...12 {
                for day in 1...28 {
                    var s = excellentDay()
                    s.day = String(format: "2026-%02d-%02d", month, day)
                    s.goldenHour = recipe.hour
                    s.lastActivity = Calendar.current.date(bySettingHour: recipe.hour, minute: 0, second: 0, of: Date())
                    recipe.tune(&s)
                    let t = PawpetTraits(day: s.day, summary: s, streakDays: 40, isCelebrating: recipe.celebrating)
                    guard t.charmAndWings == (recipe.charm, recipe.wings) else { continue }
                    if fallback == nil { fallback = (s, t) }
                    if !used.contains(t.paletteIndex) {
                        chosen = (s, t)
                        used.insert(t.paletteIndex)
                        break outer
                    }
                }
            }
            guard let pick = chosen ?? fallback else {
                write("SHOWCASE no date found for \(recipe.title)\n")
                continue
            }
            built.append((pick.0, recipe.celebrating, recipe, pick.1))
        }

        write("SHOWCASE built \(built.count) of \(recipes.count)\n")
        for (_, _, recipe, t) in built {
            write(String(format: "   [%@ %3d] %@ — %@ · %@ · %@\n",
                         t.rarityGrade, t.rarity, recipe.title,
                         t.frameName, t.pawCharmName, t.wingsName))
        }
        if let top = built.map({ $0.3 }).max(by: { $0.rarity < $1.rarity }) {
            write("SHOWCASE peak rarity = \(top.rarity)\n")
            for row in top.rarityBreakdown {
                write(String(format: "      %@ %@ %.0f/%.0f\n", row.label, row.detail, row.earned, row.maximum))
            }
        }

        let columns = 4
        let sheet = VStack(spacing: 12) {
            ForEach(0..<(built.count / columns), id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        let entry = built[index]
                        VStack(spacing: 3) {
                            PawpetView(summary: entry.0, size: 118, streakDays: 40,
                                       isCelebrating: entry.1)
                            Text(entry.2.title).font(.system(size: 10, weight: .semibold))
                            Text("\(entry.3.frameName) · \(entry.3.pawCharmName)")
                                .font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        .frame(width: 130)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.12))

        capture(sheet, name: "showcase")
    }

    /// An S-grade day: high score, heavy typing, long distances — everything a reward axis wants.
    private static func excellentDay() -> DailySummary {
        var s = DailySummary(day: "2026-01-01")
        s.activeSeconds = 7 * 3600
        s.idleSeconds = 900
        s.screenOnSeconds = 7 * 3600 + 1800     // under 8h so sunglasses don't hide the eyes
        s.screenUtilizationPercent = 90
        s.totalKeyPresses = 26_000              // over the 4,000 charm threshold
        s.characterKeyPresses = 7_000           // under 8,000 so most cats show bare eyes
        s.backspaceRatio = 0.05
        s.avgWPM = 62
        s.maxWPM = 92
        s.typingConsistency = 78
        s.totalClicks = 1_400
        s.maxClicksPerMinute = 38
        s.scrollScreens = 600                   // over 400 → wings
        s.scrollDirectionChanges = 180
        s.cursorDistanceMeters = 850
        s.dragDistanceMeters = 15
        s.totalAppSwitches = 90
        s.longestFocusSeconds = 60 * 60
        s.totalFocusSeconds = 3 * 3600
        s.longestBreakSeconds = 1_500
        s.chaosIndex = 28
        s.regretIndex = 9
        s.distinctShortcutsUsed = 9
        s.appConcentration = 55
        s.clipboardCopyCount = 30
        s.clipboardPasteCount = 30
        s.secondsOnBattery = 5 * 3600
        s.secondsOnAC = 2 * 3600
        s.networkTotalBytes = 2 * 1024 * 1024 * 1024
        s.networkDownloadBytes = 1024 * 1024 * 1024
        s.maxSimultaneousDisplays = 1
        s.firstActivity = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
        s.lastActivity = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())
        // 92 → S grade → prismatic frame.
        s.score = PawprintScore(total: 92, grade: "S", gradeColorHint: .gold,
                                headline: "훌륭한 하루", components: [])
        return s
    }

    // MARK: - Pawpet contact sheet (PAWPRINT_PAWPETS)

    /// Renders a grid of randomly-parameterised cats so the trait system can actually be eyeballed.
    /// Every axis is randomised independently, which is the only practical way to confirm that the
    /// combinations really are distinguishable rather than just numerous.
    @MainActor
    static func renderPawpetSheet(count: Int = 16) {
        var generator = SystemRandomNumberGenerator()
        // Rejection-sample: keep drawing fully random days but prefer ones whose expression hasn't
        // been shown yet. A purely random sheet clumps onto whichever states have loose thresholds
        // and doesn't demonstrate the range.
        var summaries: [DailySummary] = []
        var seen: Set<String> = []
        for _ in 0..<(count * 40) where summaries.count < count {
            let candidate = randomSummary(index: summaries.count, using: &generator)
            let t = PawpetTraits(day: candidate.day, summary: candidate)
            let key = "\(t.expression)/\(t.pawCharm)/\(t.frame)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            summaries.append(candidate)
        }
        while summaries.count < count {
            summaries.append(randomSummary(index: summaries.count, using: &generator))
        }

        write("PAWPET COMBINATIONS: \(Formatters.groupedNumber(PawpetTraits.combinationCount))\n")
        for (i, s) in summaries.enumerated() {
            let t = PawpetTraits(day: s.day, summary: s, streakDays: (i * 7) % 40)
            write("  [\(i + 1)] \(t.caption) — \(t.patternName)/\(PawpetTraits.palettes[t.paletteIndex].name)"
                  + " ears=\(t.ears) tail=\(t.tail) hat=\(t.headwear) eyewear=\(t.eyewear)"
                  + " prop=\(t.prop) collar=\(t.collar) cheek=\(t.cheekMark) aura=\(t.aura) float=\(t.floaters)\n")
        }

        let columns = 4
        let sheet = VStack(spacing: 10) {
            ForEach(0..<(count / columns), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        let s = summaries[index]
                        let pet = PawpetView(summary: s, size: 110, streakDays: (index * 7) % 40)
                        VStack(spacing: 2) {
                            pet
                            Text(pet.caption).font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(s.day).font(.system(size: 8)).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.13))

        capture(sheet, name: "pawpets")
    }

    /// Synthesises a day with independently randomised metrics, so each cell exercises a different
    /// corner of the trait space instead of re-rolling the same "typical day".
    private static func randomSummary(index: Int, using generator: inout SystemRandomNumberGenerator) -> DailySummary {
        func hour(_ h: Int) -> Date {
            Calendar.current.date(bySettingHour: h % 24, minute: 0, second: 0, of: Date()) ?? Date()
        }

        var s = DailySummary(day: String(format: "2026-%02d-%02d",
                                         Int.random(in: 1...12, using: &generator),
                                         Int.random(in: 1...28, using: &generator)))
        // A real day is almost never under five minutes, so don't make one in two cats asleep.
        s.activeSeconds = Int.random(in: 0...9, using: &generator) == 0
            ? Int.random(in: 60...290, using: &generator)
            : Int.random(in: 1800...28800, using: &generator)
        s.idleSeconds = Int.random(in: 0...20000, using: &generator)
        s.screenOnSeconds = s.activeSeconds + Int.random(in: 0...30000, using: &generator)
        s.screenUtilizationPercent = Int.random(in: 10...95, using: &generator)
        s.totalKeyPresses = Int.random(in: 0...40000, using: &generator)
        s.scrollScreens = Double.random(in: 0...900, using: &generator)
        s.characterKeyPresses = Int(Double(s.totalKeyPresses) * 0.7)
        s.backspaceRatio = Double.random(in: 0...0.45, using: &generator)
        s.maxWPM = Double.random(in: 0...150, using: &generator)
        s.totalClicks = Int.random(in: 0...4000, using: &generator)
        s.maxClicksPerMinute = Int.random(in: 0...90, using: &generator)
        s.scrollDirectionChanges = Int.random(in: 0...600, using: &generator)
        s.totalAppSwitches = Int.random(in: 0...400, using: &generator)
        s.longestFocusSeconds = Int.random(in: 0...5400, using: &generator)
        s.longestBreakSeconds = Int.random(in: 0...10800, using: &generator)
        s.chaosIndex = Double.random(in: 0...100, using: &generator)
        s.regretIndex = Double.random(in: 0...60, using: &generator)
        s.distinctShortcutsUsed = Int.random(in: 0...16, using: &generator)
        s.audioOutputDeviceChangeCount = Int.random(in: 0...5, using: &generator)
        s.lidOpenCount = Int.random(in: 0...6, using: &generator)
        s.secondsOnAC = Int.random(in: 0...30000, using: &generator)
        s.secondsOnBattery = Int.random(in: 0...20000, using: &generator)
        s.totalSleepSeconds = Int.random(in: 0...14400, using: &generator)
        s.elevatedThermalSeconds = Bool.random(using: &generator) ? Int.random(in: 0...600, using: &generator) : 0
        s.networkTotalBytes = UInt64.random(in: 0...(12 * 1024 * 1024 * 1024), using: &generator)
        // Everything a persona or a cat might key off, so the spread report exercises the whole
        // candidate list rather than only the handful of fields that happened to be populated.
        s.totalFocusSeconds = Int.random(in: 0...s.activeSeconds, using: &generator)
        s.typingConsistency = Int.random(in: 0...100, using: &generator)
        s.avgWPM = Double.random(in: 0...80, using: &generator)
        s.scrollScreens = Double.random(in: 0...600, using: &generator)
        s.cursorDistanceMeters = Double.random(in: 0...900, using: &generator)
        s.dragDistanceMeters = Double.random(in: 0...60, using: &generator)
        s.clipboardCopyCount = Int.random(in: 0...120, using: &generator)
        s.clipboardPasteCount = Int.random(in: 0...120, using: &generator)
        s.appConcentration = Int.random(in: 10...95, using: &generator)
        s.maxSimultaneousDisplays = Int.random(in: 1...3, using: &generator)
        s.networkDownloadBytes = UInt64(Double(s.networkTotalBytes) * 0.8)
        s.shortcutCounts = [.copy: Int.random(in: 0...400, using: &generator),
                            .paste: Int.random(in: 0...400, using: &generator),
                            .undo: Int.random(in: 0...200, using: &generator)]
        s.appUsage = (0..<Int.random(in: 1...18, using: &generator)).map { i in
            AppUsageStat(bundleID: "app.\(i)", appName: "App \(i)",
                         totalSeconds: Double.random(in: 60...3600, using: &generator),
                         activationCount: Int.random(in: 1...40, using: &generator))
        }
        s.goldenHour = Int.random(in: 0...23, using: &generator)
        s.firstActivity = hour(Int.random(in: 5...11, using: &generator))
        s.lastActivity = hour(Int.random(in: 0...23, using: &generator))
        let total = Int.random(in: 0...100, using: &generator)
        s.score = PawprintScore(total: total, grade: "B", gradeColorHint: .blue,
                                headline: "테스트", components: [])
        return s
    }

    // MARK: - Layout snapshots (PAWPRINT_SNAPSHOT)

    @MainActor
    static func run() {
        let center = ActivityCenter.shared
        var out = "PERCENTILES (\(center.todayPercentiles.count)):\n"
        for r in center.todayPercentiles {
            out += "   \(r.title): \(r.displayValue) → \(r.label) [\(r.totalDays)일 중 \(r.rank)위]\n"
        }
        if let h = center.headlinePercentile {
            out += "HEADLINE: \(PercentileEngine.headline(for: h))\n"
        }
        out += "RECORD STANDINGS (\(RecordTracker.shared.standings.count)):\n"
        for st in RecordTracker.shared.standings {
            out += "   \(st.best.title): \(Int(st.progress*100))% of \(st.best.formatted(st.best.best))\n"
        }
        var pools: [FunFact.Topic: [String]] = [:]
        for f in center.todaySummary.funFacts { pools[f.topic, default: []].append(f.text) }
        out += "FUN FACT POOLS:\n"
        for topic in FunFact.Topic.allCases {
            guard let pool = pools[topic] else { continue }
            out += "   \(topic.rawValue) (\(pool.count)):\n"
            for line in pool { out += "      · \(line)\n" }
        }
        out += "HUD available: \(LiveHUDController.shared.isVisible ? "visible" : "hidden")\n"
        write(out)

        capture(OnboardingView(onFinish: {}).checklist.frame(width: 428).padding(16), name: "onboarding")
        capture(LiveHUDView().padding(6), name: "hud")
        capture(LiveHUDView(showingOpacity: true).padding(6), name: "hud_opacity")
        capture(PawpetCard(summary: center.todaySummary, streakDays: center.currentStreak)
                    .frame(width: 360), name: "pawpetcard")
        capture(EnergyCard(lines: center.todaySummary.energyFacts.map(\.text),
                           drainedPercent: center.todaySummary.batteryDrainedPercent)
                    .frame(width: 360), name: "energycard")
        capture(PawpetGalleryView().frame(width: 360), name: "gallery")
        capture(PawpetDetailView(summary: center.todaySummary,
                                 streakDays: center.currentStreak, onClose: {})
                    .content.frame(width: 400),
                name: "catdetail")
        capture(CalendarView().frame(width: 360), name: "calendar")
        capture(RecordsView().frame(width: 360), name: "records")
        capture(TodayView().frame(width: 360), name: "today")
    }

    @MainActor
    private static func capture<V: View>(_ view: V, name: String) {
        let renderer = ImageRenderer(content: view.padding(8).background(Color(white: 0.15)))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            write("SNAPSHOT \(name) FAILED\n")
            return
        }
        try? png.write(to: URL(fileURLWithPath: "/tmp/pawprint_\(name).png"))
        write("SNAPSHOT \(name) \(Int(image.size.width))x\(Int(image.size.height))\n")
    }
}
