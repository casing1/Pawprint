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

    // MARK: - Record celebration probe (PAWPRINT_RECORD_PROBE)

    /// Reports whether a broken record is pending and what has been marked as already celebrated.
    /// Run it twice across a relaunch: the second run must report nothing pending.
    @MainActor
    static func probeRecordCelebration() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            let center = ActivityCenter.shared
            let pending = RecordTracker.shared.pendingCelebration
            write("RECORD pending=\(pending?.best.title ?? "none")\n")
            write("RECORD persisted=\(center.settings.celebratedRecords.sorted().joined(separator: ","))\n")
            exit(0)
        }
    }

    // MARK: - Automatic scheduler probe (PAWPRINT_UPDATE_PROBE)

    /// Waits out the launch delay and reports what the *scheduler* found, with no manual check
    /// involved — the path a real user is on, which is otherwise entirely silent.
    @MainActor
    static func probeAutomaticUpdate() {
        Task { @MainActor in
            let settings = ActivityCenter.shared.settings
            write("AUTOUPDATE enabled=\(settings.updateCheckEnabled) "
                  + "automatic=\(settings.updateCheckAutomatically) feed=\(settings.updateFeedURL)\n")
            for _ in 0..<12 {
                try? await Task.sleep(for: .seconds(2))
                if case .available(let release) = UpdateChecker.shared.state {
                    write("AUTOUPDATE scheduler offered \(release.version)\n")
                    exit(0)
                }
            }
            write("AUTOUPDATE no update offered — state=\(UpdateChecker.shared.state)\n")
            exit(1)
        }
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

    static let bannerStates: [(String, UpdateChecker.State)] = [
        ("available", .available(UpdateRelease(version: "0.2.0", build: "9", notes: nil,
                                               downloadURL: "https://example.invalid/a.zip",
                                               minimumSystemVersion: nil, publishedAt: nil,
                                               signature: nil))),
        ("downloading", .downloading(progress: 0.45)),
        ("ready", .readyToInstall(UpdateRelease(version: "0.2.0", build: "9", notes: nil,
                                                downloadURL: "https://example.invalid/a.zip",
                                                minimumSystemVersion: nil, publishedAt: nil,
                                                signature: nil)))
    ]

    // MARK: - README banner (PAWPRINT_BANNER)

    /// Renders the repository banner from the app's own drawing code, so the artwork can never
    /// drift from what the app actually produces.
    @MainActor
    static func renderBanner() {
        // Four S-grade cats, each with a different charm, picked by walking dates until the
        // date-seeded draw lands on the one we want.
        let wanted: [(PawpetTraits.PawCharm, PawpetTraits.Wings)] = [
            (.star, .feathered), (.flame, .ember), (.orb, .crystal), (.crystal, .feathered)
        ]
        var cats: [(DailySummary, Bool)] = []
        var usedPalettes: Set<Int> = []

        for (charm, wings) in wanted {
            var fallback: (DailySummary, Bool)?
            search: for month in 1...12 {
                for day in 1...28 {
                    var summary = excellentDay()
                    summary.day = String(format: "2026-%02d-%02d", month, day)
                    let celebrating = cats.isEmpty
                    let traits = PawpetTraits(day: summary.day, summary: summary,
                                              streakDays: 40, isCelebrating: celebrating)
                    guard traits.charmAndWings == (charm, wings) else { continue }
                    if fallback == nil { fallback = (summary, celebrating) }
                    if !usedPalettes.contains(traits.paletteIndex) {
                        usedPalettes.insert(traits.paletteIndex)
                        cats.append((summary, celebrating))
                        break search
                    }
                }
            }
            if cats.count < wanted.firstIndex(where: { $0 == (charm, wings) })! + 1,
               let fallback { cats.append(fallback) }
        }

        let banner = ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.10, blue: 0.16),
                         Color(red: 0.16, green: 0.13, blue: 0.24),
                         Color(red: 0.10, green: 0.15, blue: 0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Text and cats as one centred group: a full-width HStack with a Spacer left a dead
            // gap in the middle at banner proportions.
            HStack(spacing: 34) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.35))
                        Text("Pawprint")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Your Mac, as a cat you collect every day.")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("A quiet menu bar tracker that never records what you type.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                HStack(spacing: -10) {
                    ForEach(Array(cats.enumerated()), id: \.offset) { index, entry in
                        PawpetView(summary: entry.0, size: 116, streakDays: 40,
                                   isCelebrating: entry.1, showsAura: false)
                            .rotationEffect(.degrees(Double(index - 1) * 4))
                    }
                }
            }
        }
        .frame(width: 1200, height: 272)

        capture(banner, name: "banner", scale: 2, bare: true)
    }

    // MARK: - DMG background (PAWPRINT_DMG_BG)

    /// Installer window backdrop: 1200x800 px for a 600x400 pt window (2x for Retina).
    ///
    /// The layout has to leave two clear landing zones — the app icon on the left, the
    /// Applications alias on the right — because `make_dmg.sh` positions the real icons at fixed
    /// coordinates on top of this. Everything decorative stays below or outside those rectangles.
    @MainActor
    static func renderDMGBackground() {
        // Icon centres in *points*, matching the AppleScript in make_dmg.sh.
        let leftCenter = CGFloat(150)
        let rightCenter = CGFloat(450)
        let iconY = CGFloat(170)

        // Three cats loitering along the bottom, drawn by the same code the app uses.
        // Deliberately *not* S-grade: a prismatic frame cropped by the window edge reads as a
        // stray coloured box. Scoring low drops the frame and leaves just the cat.
        var cats: [DailySummary] = []
        var usedPalettes: Set<Int> = []
        outer: for month in 1...12 {
            for day in 1...28 {
                var summary = excellentDay()
                summary.day = String(format: "2026-%02d-%02d", month, day)
                summary.score = PawprintScore(total: 24, grade: "D", gradeColorHint: .gray,
                                              headline: "", components: [])
                summary.scrollScreens = 100      // below the wing threshold
                summary.cursorDistanceMeters = 100
                let traits = PawpetTraits(day: summary.day, summary: summary, streakDays: 40)
                guard traits.frame == .none,
                      !usedPalettes.contains(traits.paletteIndex) else { continue }
                usedPalettes.insert(traits.paletteIndex)
                cats.append(summary)
                if cats.count == 3 { break outer }
            }
        }

        let background = ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.18),
                         Color(red: 0.17, green: 0.14, blue: 0.26),
                         Color(red: 0.11, green: 0.16, blue: 0.24)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Cats peeking up from the bottom edge, cropped by the window so they read as
            // decoration rather than content competing with the two icons.
            HStack(alignment: .bottom, spacing: 84) {
                ForEach(Array(cats.enumerated()), id: \.offset) { index, summary in
                    PawpetView(summary: summary, size: index == 1 ? 124 : 104,
                               streakDays: 40, showsAura: false)
                        .opacity(0.42)
                        .offset(y: index == 1 ? 26 : 34)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            // A small paw trail arcing from the app toward Applications: the instruction, drawn.
            Canvas { context, size in
                let steps = 9
                for step in 0..<steps {
                    let t = CGFloat(step) / CGFloat(steps - 1)
                    let x = leftCenter + (rightCenter - leftCenter) * t
                    // Gentle arc that dips below the icons and never crosses them.
                    let y = iconY + 96 + sin(Double(t) * .pi) * 14
                    var paw = context
                    paw.translateBy(x: x, y: CGFloat(y))
                    paw.rotate(by: .degrees(Double(t) * 26 - 13))
                    let scale = CGFloat(9)
                    let opacity = 0.10 + Double(t) * 0.16
                    paw.fill(
                        Path(ellipseIn: CGRect(x: -scale * 0.60, y: -scale * 0.28,
                                               width: scale * 1.20, height: scale * 1.02)),
                        with: .color(.white.opacity(opacity))
                    )
                    for (tx, ty, tw) in [(-0.60, -1.00, 0.40), (-0.20, -1.26, 0.42),
                                         (0.24, -1.24, 0.42), (0.62, -0.94, 0.38)] {
                        paw.fill(
                            Path(ellipseIn: CGRect(x: scale * CGFloat(tx) - scale * CGFloat(tw) / 2,
                                                   y: scale * CGFloat(ty),
                                                   width: scale * CGFloat(tw),
                                                   height: scale * CGFloat(tw) * 1.2)),
                            with: .color(.white.opacity(opacity * 0.9))
                        )
                    }
                }
            }

            VStack(spacing: 5) {
                Text("Pawprint")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Drag Pawprint into your Applications folder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                Spacer()
            }
            .padding(.top, 30)

            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .position(x: (leftCenter + rightCenter) / 2, y: iconY)
        }
        .frame(width: 600, height: 400)
        .clipped()

        write("DMGBG cats=\(cats.count)\n")
        // scale 2 → 1200x800 px, which is what a 600x400 pt window wants on Retina.
        capture(background, name: "dmg_background", scale: 2, bare: true)
    }

    // MARK: - Language switch probe (PAWPRINT_SWITCH)

    /// Switches language at runtime and checks that *generated* text follows.
    ///
    /// Simple lookups were never the risk. Summary sentences, highlights, personal-best titles
    /// and the persona are produced by the engines and then cached or stored, so they used to
    /// keep whatever language was active when they were first computed.
    @MainActor
    static func probeLanguageSwitch() {
        let center = ActivityCenter.shared

        func sample() -> [String: String] {
            var out: [String: String] = [:]
            out["summary"] = center.todaySummary.summarySentence
            out["persona"] = center.todaySummary.persona?.title ?? "-"
            out["score"] = center.todaySummary.score?.headline ?? "-"
            out["highlight"] = center.todaySummary.highlights.first?.title ?? "-"
            out["funFact"] = center.todaySummary.funFacts.first?.text ?? "-"
            out["personalBest"] = center.personalBests.first?.title ?? "-"
            out["quest"] = center.quests.first?.displayTitle ?? "-"
            out["metric"] = MetricCatalog.all.first?.title ?? "-"
            return out
        }

        func hasHangul(_ text: String) -> Bool {
            text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
        }

        var settings = center.settings
        settings.language = .korean
        center.updateSettings(settings)
        let korean = sample()

        settings.language = .english
        center.updateSettings(settings)
        let english = sample()

        var stale: [String] = []
        for (field, koreanValue) in korean.sorted(by: { $0.key < $1.key }) {
            let englishValue = english[field] ?? ""
            write("SWITCH \(field)\n    ko: \(koreanValue)\n    en: \(englishValue)\n")
            // A field that stayed identical, or still carries Hangul in English, never rebuilt.
            if koreanValue != "-" && (koreanValue == englishValue || hasHangul(englishValue)) {
                stale.append(field)
            }
        }

        // Put it back so the probe doesn't leave the app in English.
        settings.language = .korean
        center.updateSettings(settings)

        write(stale.isEmpty ? "SWITCH OK — every field followed the language\n"
                            : "SWITCH STALE: \(stale.joined(separator: ", "))\n")
        exit(stale.isEmpty ? 0 : 1)
    }

    // MARK: - Clipboard shape probe (PAWPRINT_CLIPBOARD)

    /// Copies a share card and reports what actually landed on the pasteboard. The bug this
    /// guards against is invisible in the app: the copy "works", and only a receiver that reads
    /// every item — a messaging app — reveals that there were two.
    @MainActor
    static func probeClipboard() {
        let center = ActivityCenter.shared
        let metrics = MetricCatalog.all.filter(\.availableAsCard)
        let result = ShareCardRenderer.copyToPasteboard(.today(center.todaySummary), metrics: Array(metrics.prefix(4)))
        write("CLIPBOARD copy result: \(result)\n")

        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems ?? []
        write("CLIPBOARD items: \(items.count)\n")
        for (index, item) in items.enumerated() {
            write("   item \(index): \(item.types.map(\.rawValue).joined(separator: ", "))\n")
        }
        let imageItems = items.filter { item in
            item.types.contains(.png) || item.types.contains(.tiff)
        }
        write(imageItems.count == 1
              ? "CLIPBOARD OK — one image, \(imageItems[0].types.count) representations\n"
              : "CLIPBOARD BROKEN — \(imageItems.count) separate images\n")
        exit(imageItems.count == 1 ? 0 : 1)
    }

    // MARK: - Localization audit (PAWPRINT_L10N)

    /// Walks every catalog and enum that renders text and reports anything that came back as a
    /// raw key — the symptom of a translation resolved before its pack was loaded.
    @MainActor
    static func auditLocalization() {
        func check(_ label: String, _ values: [String]) -> Int {
            let broken = values.filter { $0.contains(".") && $0.range(of: "^[a-zA-Z]+\\.[0-9a-f]{8}$",
                                                                     options: .regularExpression) != nil }
            if !broken.isEmpty {
                write("L10N BROKEN \(label): \(broken.joined(separator: ", "))\n")
            }
            return broken.count
        }

        var broken = 0
        for language in [AppLanguage.korean, .english] {
            LocalizationManager.shared.apply(language)
            broken += check("metric titles", MetricCatalog.all.map(\.title))
            broken += check("metric explanations", MetricCatalog.all.map(\.explanation))
            broken += check("quest titles", QuestTrack.allCases.map(\.title))
            broken += check("quest explanations", QuestTrack.allCases.map(\.explanation))
            broken += check("ranks", QuestProgress.ranks.map(\.name))
            broken += check("overall titles", OverallLevel.titles.map(\.name))
            broken += check("excluded apps", AppSettings.defaultExcludedApps.map(\.displayName))
            broken += check("palettes", (0..<PawpetTraits.palettes.count).map { PawpetTraits.paletteName($0) })
            broken += check("eye colours", (0..<PawpetTraits.eyeColors.count).map { PawpetTraits.eyeColorName($0) })
            broken += check("explanations", [MetricExplanations.regret.title, MetricExplanations.chaos.body,
                                             MetricExplanations.score.detail, MetricExplanations.energy.body])
            let sample = MetricCatalog.all.first(where: { $0.id == "totalKeys" })?.title ?? "?"
            write("L10N \(language) totalKeys title = \(sample)\n")
        }
        write(broken == 0 ? "L10N OK — no raw keys\n" : "L10N \(broken) BROKEN\n")
        exit(broken == 0 ? 0 : 1)
    }

    // MARK: - Cat wall for the README (PAWPRINT_WALL)

    /// A dense wall of high-grade cats.
    ///
    /// A tidy 4x4 of identically-framed cats undersold the point: the interesting claim is the
    /// *range*, so this deliberately mixes grades (bronze through prismatic) to vary the frame
    /// colours, and greedily picks for distinct coat, charm, wings and expression rather than
    /// taking the first N dates that match.
    @MainActor
    static func renderCatWall(columns: Int = 8, rows: Int = 6) {
        let wanted = columns * rows

        /// Score bands, cycled so frames alternate instead of being a field of rainbows.
        let bands: [Int] = [92, 88, 78, 95, 62, 74, 90, 45, 86, 71, 96, 55]

        /// Metric tweaks that push the expression around, cycled independently of the bands.
        let moods: [(String, (inout DailySummary) -> Void)] = [
            ("determined", { $0.maxWPM = 135 }),
            ("focused", { $0.longestFocusSeconds = 95 * 60 }),
            ("surprised", { $0.maxClicksPerMinute = 82; $0.longestFocusSeconds = 15 * 60 }),
            ("mischief", { $0.totalAppSwitches = 260; $0.longestFocusSeconds = 15 * 60 }),
            ("zen", { $0.longestBreakSeconds = 3 * 3600; $0.longestFocusSeconds = 15 * 60 }),
            ("dizzy", { $0.backspaceRatio = 0.36 }),
            ("chaotic", { $0.chaosIndex = 84 }),
            ("wide", { $0.longestFocusSeconds = 15 * 60 }),
            ("tired", { $0.screenOnSeconds = 9 * 3600; $0.screenUtilizationPercent = 22;
                        $0.longestFocusSeconds = 15 * 60 }),
            ("content", { $0.longestFocusSeconds = 15 * 60; $0.maxWPM = 70 })
        ]

        var chosen: [(DailySummary, Bool)] = []
        var seenSignature: Set<String> = []
        var index = 0

        // Two passes: the first insists every cat is a new combination, the second fills any
        // shortfall without that constraint so the grid is always complete.
        for requireNew in [true, false] {
            for month in 1...12 where chosen.count < wanted {
                for day in 1...28 where chosen.count < wanted {
                    var summary = excellentDay()
                    summary.day = String(format: "2026-%02d-%02d", month, day)
                    let band = bands[index % bands.count]
                    let mood = moods[(index / bands.count + index) % moods.count]
                    summary.score = PawprintScore(total: band, grade: "S", gradeColorHint: .gold,
                                                  headline: "", components: [])
                    mood.1(&summary)
                    summary.goldenHour = (index * 5) % 24
                    let celebrating = index % 11 == 0
                    let traits = PawpetTraits(day: summary.day, summary: summary,
                                              streakDays: 40, isCelebrating: celebrating)
                    let signature = "\(traits.paletteIndex)/\(traits.pattern)/\(traits.pawCharm)"
                        + "/\(traits.wings)/\(traits.frame)/\(traits.expression)"
                    if requireNew && seenSignature.contains(signature) { continue }
                    seenSignature.insert(signature)
                    chosen.append((summary, celebrating))
                    index += 1
                }
            }
        }

        write("WALL \(chosen.count) cats, \(seenSignature.count) distinct combinations\n")

        let wall = VStack(spacing: 14) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(0..<columns, id: \.self) { column in
                        let entry = chosen[row * columns + column]
                        PawpetView(summary: entry.0, size: 104, streakDays: 40,
                                   isCelebrating: entry.1)
                    }
                }
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.13),
                         Color(red: 0.12, green: 0.10, blue: 0.19),
                         Color(red: 0.08, green: 0.12, blue: 0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )

        capture(wall, name: "cat-wall", scale: 2, bare: true)
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

        // A plain grid: the README shows this to people who don't read Korean, and the caption
        // rows underneath were unreadable at the width GitHub renders it.
        let columns = 4
        let sheet = VStack(spacing: 10) {
            ForEach(0..<(built.count / columns), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<columns, id: \.self) { column in
                        let entry = built[row * columns + column]
                        PawpetView(summary: entry.0, size: 132, streakDays: 40,
                                   isCelebrating: entry.1)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.12))

        capture(sheet, name: "showcase", bare: true)
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
            write("  [\(i + 1)] \(t.caption) — \(t.patternName)/\(PawpetTraits.paletteName(t.paletteIndex))"
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
        // Render everything in whichever language PAWPRINT_LANG names, so both packs get eyes on.
        if let code = ProcessInfo.processInfo.environment["PAWPRINT_LANG"] {
            LocalizationManager.shared.apply(code == "en" ? .english : .korean)
            write("LANG forced to \(code)\n")
        }

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

        // Drive the banner through each state it can be in — it is the one piece of UI a user
        // only ever sees when something is already happening.
        for (label, state) in DebugSnapshot.bannerStates {
            UpdateChecker.shared.debugForceState(state)
            capture(UpdateBanner().frame(width: 340).padding(8), name: "banner_\(label)")
        }
        UpdateChecker.shared.debugForceState(.idle)

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
    /// `bare` skips the debug matte — fine for inspecting a layout, wrong for artwork that ships.
    private static func capture<V: View>(_ view: V, name: String, scale: CGFloat = 2, bare: Bool = false) {
        let matted = AnyView(bare ? AnyView(view) : AnyView(view.padding(8).background(Color(white: 0.15))))
        let renderer = ImageRenderer(content: matted)
        renderer.scale = scale
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
