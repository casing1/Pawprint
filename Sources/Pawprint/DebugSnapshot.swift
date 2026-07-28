import AppKit
import ApplicationServices
import IOKit.hid
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
                                              streakDays: 40, setARecord: celebrating)
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
                        PawpetView(summary: entry.0, size: 116, streakDays: 40, showsAura: false,
                                   traitsOverride: PawpetTraits(day: entry.0.day, summary: entry.0,
                                                                streakDays: 40, setARecord: entry.1))
                            .rotationEffect(.degrees(Double(index - 1) * 4))
                    }
                }
            }
        }
        .frame(width: 1200, height: 272)

        capture(banner, name: "banner", scale: 2, bare: true)
    }

    // MARK: - Menu bar icon sheet (PAWPRINT_MENUCAT)

    /// Draws the menu bar cat big enough to judge, and at the size it will actually be.
    ///
    /// A 17pt template image is far too small to design against, and a magnified view alone is
    /// not enough to trust — a shape that looks fine at 8x can smudge into a blob at 1x. So both
    /// are rendered: a sheet of poses, and the real animation cycle on menu-bar-like strips in
    /// both appearances, beside the paw it is an alternative to.
    @MainActor
    static func renderMenuBarCatSheet() {
        // Four points around the tail's wave plus a blink, which is what there is to judge.
        let poses: [(String, MenuBarCat.Pose)] = [
            ("wave 0",  .init(tailPhase: 0.0, earSway: -0.55)),
            ("wave ¼",  .init(tailPhase: 0.25, earSway: 0)),
            ("wave ½",  .init(tailPhase: 0.5, earSway: 0.55)),
            ("wave ¾",  .init(tailPhase: 0.75, earSway: 0)),
            ("blink",   .init(tailPhase: 0.3, earSway: 0.2, blink: 1)),
            ("asleep",  .init(tailPhase: 0.4, blink: 1, asleep: true, sleepDrift: 0.45))
        ]

        // Drawn at a large point size rather than scaled up from 17pt, so this shows the geometry
        // rather than the rasteriser.
        let big = HStack(spacing: 18) {
            ForEach(Array(poses.enumerated()), id: \.offset) { _, pose in
                VStack(spacing: 8) {
                    Image(nsImage: tinted(MenuBarCat.image(
                        pose: pose.1, height: 130, canvasWidth: 240, canvasHeight: 160)))
                        .frame(width: 240, height: 160)
                    Text(pose.0).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(24)
        .background(Color(white: 0.12))
        capture(big, name: "menucat_big", scale: 1, bare: true)

        // The whole 24-frame cycle at real size, which is the only way to see whether the wag
        // actually reads or just jitters.
        let cycle = VStack(spacing: 0) {
            ForEach([true, false], id: \.self) { dark in
                HStack(spacing: 3) {
                    ForEach(Array(stride(from: 0, to: MenuBarIconAnimator.frameCount, by: 2)),
                            id: \.self) { step in
                        Image(nsImage: tinted(
                            MenuBarCat.image(pose: MenuBarIconAnimator.catPoses[step],
                                             height: MenuBarIconAnimator.catHeight,
                                             canvasWidth: MenuBarIconAnimator.catCanvasWidth,
                                             canvasHeight: 22),
                            white: dark))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(dark ? Color(white: 0.13) : Color(white: 0.93))
            }
        }
        .frame(width: 860)
        capture(cycle, name: "menucat_cycle", scale: 3, bare: true)

        // Asleep, big and small. This is what the icon shows most of the time — whenever nobody
        // is at the keyboard — so it gets the same scrutiny as the awake pose.
        let sleepBig = HStack(spacing: 18) {
            ForEach([0.1, 0.35, 0.6, 0.85], id: \.self) { drift in
                Image(nsImage: tinted(MenuBarCat.image(
                    pose: .init(tailPhase: CGFloat(drift), blink: 1, asleep: true,
                                sleepDrift: CGFloat(drift)),
                    height: 130, canvasWidth: 240, canvasHeight: 160)))
                    .frame(width: 240, height: 160)
            }
        }
        .padding(24)
        .background(Color(white: 0.12))
        capture(sleepBig, name: "menucat_sleep_big", scale: 1, bare: true)

        let sleepStrip = VStack(spacing: 0) {
            ForEach([true, false], id: \.self) { dark in
                HStack(spacing: 2) {
                    ForEach(Array(stride(from: 0, to: MenuBarIconAnimator.sleepFrameCount, by: 3)),
                            id: \.self) { step in
                        Image(nsImage: tinted(
                            MenuBarCat.image(pose: MenuBarIconAnimator.sleepPoses[step],
                                             height: MenuBarIconAnimator.catHeight,
                                             canvasWidth: MenuBarIconAnimator.catCanvasWidth,
                                             canvasHeight: 22),
                            white: dark))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(dark ? Color(white: 0.13) : Color(white: 0.93))
            }
        }
        .frame(width: 620)
        capture(sleepStrip, name: "menucat_sleep", scale: 3, bare: true)

        // Side by side with the paw, at the size and spacing of a real menu bar.
        let compare = VStack(spacing: 0) {
            ForEach([true, false], id: \.self) { dark in
                HStack(spacing: 18) {
                    Spacer(minLength: 0)
                    Image(nsImage: tinted(
                        MenuBarIconAnimator.previewImage(for: .paw), white: dark))
                    Text("100 WPM")
                        .font(.system(size: 12))
                        .foregroundStyle(dark ? .white : .black)
                    Image(nsImage: tinted(
                        MenuBarIconAnimator.previewImage(for: .cat), white: dark))
                    Text("100 WPM")
                        .font(.system(size: 12))
                        .foregroundStyle(dark ? .white : .black)
                }
                .padding(.horizontal, 14)
                .frame(height: 24)
                .background(dark ? Color(white: 0.13) : Color(white: 0.93))
            }
        }
        .frame(width: 260)
        capture(compare, name: "menucat_compare", scale: 4, bare: true)
    }

    /// Template images carry no colour of their own, so they have to be tinted to be seen.
    @MainActor
    private static func tinted(_ image: NSImage, white: Bool = true) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        (white ? NSColor.white : NSColor.black).set()
        NSRect(origin: .zero, size: image.size).fill()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size),
                   operation: .destinationIn, fraction: 1)
        output.unlockFocus()
        return output
    }

    // MARK: - GitHub social preview (PAWPRINT_SOCIAL)

    /// The repository's social card: 1280x640, the size GitHub asks for.
    ///
    /// GitHub crops this card differently depending on where it is shown — the repo page, a link
    /// unfurled in Slack, a tweet — so everything that matters stays inside a 64pt inset, well
    /// clear of the 40pt they recommend. The corners hold nothing but background on purpose.
    ///
    /// Rendered at scale 1: 1280x640 points is already the pixel size wanted, and scale 2 would
    /// produce a 2560x1280 file that GitHub only downsamples.
    @MainActor
    static func renderSocialCard() {
        // Five S-grade cats with different charms and coats, found the same way the README wall
        // does it: walk dates until the date-seeded draw lands on the combination we want.
        let wanted: [(PawpetTraits.PawCharm, PawpetTraits.Wings)] = [
            (.star, .feathered), (.flame, .ember), (.orb, .crystal),
            (.crystal, .feathered), (.gauntlet, .ember)
        ]
        var cats: [(DailySummary, PawpetTraits)] = []
        var usedPalettes: Set<Int> = []

        for (charm, wings) in wanted {
            var fallback: (DailySummary, PawpetTraits)?
            search: for month in 1...12 {
                for day in 1...28 {
                    var summary = excellentDay()
                    summary.day = String(format: "2026-%02d-%02d", month, day)
                    let traits = PawpetTraits(day: summary.day, summary: summary,
                                              streakDays: 40, setARecord: cats.isEmpty)
                    guard traits.charmAndWings == (charm, wings) else { continue }
                    if fallback == nil { fallback = (summary, traits) }
                    if !usedPalettes.contains(traits.paletteIndex) {
                        usedPalettes.insert(traits.paletteIndex)
                        cats.append((summary, traits))
                        break search
                    }
                }
            }
            if cats.count < wanted.count, let fallback,
               !cats.contains(where: { $0.1.charmAndWings == (charm, wings) }) {
                cats.append(fallback)
            }
        }

        let card = ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.10, blue: 0.16),
                         Color(red: 0.16, green: 0.13, blue: 0.24),
                         Color(red: 0.10, green: 0.15, blue: 0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // A warm glow behind the cats so the right half doesn't read as empty.
            RadialGradient(colors: [Color(red: 1.0, green: 0.78, blue: 0.35).opacity(0.16), .clear],
                           center: .init(x: 0.5, y: 0.72), startRadius: 0, endRadius: 460)

            VStack(spacing: 34) {
                VStack(spacing: 14) {
                    HStack(spacing: 16) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.35))
                        Text("Pawprint")
                            .font(.system(size: 84, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Your Mac, as a cat you collect every day.")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                    Text("A quiet menu bar tracker that never records what you type.")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.52))
                }

                // Barely overlapping. At -14 the rainbow frames clipped each other and the row
                // read as one striped block rather than five separate cats.
                HStack(spacing: 4) {
                    ForEach(Array(cats.prefix(5).enumerated()), id: \.offset) { index, entry in
                        PawpetView(summary: entry.0, size: 150, streakDays: 40, showsAura: false,
                                   traitsOverride: entry.1)
                            .rotationEffect(.degrees(Double(index - 2) * 3.5))
                    }
                }

                HStack(spacing: 10) {
                    ForEach(["macOS 14+", "Apple Silicon + Intel", "100% local", "Open source"],
                            id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white.opacity(0.10)))
                    }
                }
            }
            .padding(64)
        }
        .frame(width: 1280, height: 640)

        capture(card, name: "social", scale: 1, bare: true)

        if ProcessInfo.processInfo.environment["PAWPRINT_SOCIAL_SAFE"] != nil {
            capture(card.overlay(
                Rectangle().strokeBorder(Color.red.opacity(0.9), lineWidth: 2).padding(40)
            ), name: "social_safe", scale: 1, bare: true)
        }
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

    // MARK: - Item catalog + hidden achievements (PAWPRINT_ITEMS)

    /// Checks the two new reference sheets without a screen.
    ///
    /// Three things can silently go wrong here and none of them are visible from a screenshot:
    /// a condition string can lose its substituted threshold, the rarity points can stop adding
    /// up to 100, and a hidden achievement can be written so it never fires (or fires for
    /// everyone on day one). All three are checked.
    @MainActor
    static func probeItemCatalog() {
        var failures = 0

        for language in [AppLanguage.korean, .english] {
            LocalizationManager.shared.apply(language)
            write("\n=== \(language) ===\n")

            var groupPoints = 0
            for group in PawpetItemCatalog.groups {
                let cap = group.maximum.map { "  (max \($0))" } ?? ""
                write("[\(group.title)]\(cap) \(group.summary)\n")
                groupPoints += group.maximum ?? 0
                for item in group.items {
                    let points = item.points.map { String(format: "%3d", $0) } ?? "  -"
                    write("   \(points)  \(item.name) — \(item.condition)\n")
                    // A condition that still contains %@ never got its threshold substituted.
                    if item.condition.contains("%@") || item.name.contains("%@") {
                        write("FAIL unsubstituted placeholder: \(item.name)\n"); failures += 1
                    }
                    // A raw key means the pack is missing an entry.
                    if item.name.contains(".") && item.name.range(of: "^[a-zA-Z]+\\.", options: .regularExpression) != nil {
                        write("FAIL raw key: \(item.name)\n"); failures += 1
                    }
                }
            }
            if groupPoints != 100 {
                write("FAIL rarity points total \(groupPoints), expected 100\n"); failures += 1
            }

            write("\n[hidden achievements]\n")
            for id in AchievementID.hidden {
                write("   \(id.emoji) \(id.title) — \(id.detail)\n")
                if id.title.contains(".") { write("FAIL raw key: \(id.title)\n"); failures += 1 }
            }
        }

        // Every hidden condition must fire for a day built to satisfy it, and no hidden condition
        // may fire for a blank day — the two ways a condition can be wrong without looking wrong.
        LocalizationManager.shared.apply(.korean)
        let engine = AchievementEngine.shared
        let blank = DailySummary(day: "2026-01-01")
        for id in AchievementID.hidden where engine.satisfies(id, summary: blank, currentStreak: 0) {
            write("FAIL \(id.rawValue) fires on an empty day\n"); failures += 1
        }
        for (id, summary) in hiddenAchievementFixtures() {
            if !engine.satisfies(id, summary: summary, currentStreak: 0) {
                write("FAIL \(id.rawValue) does not fire on its own fixture\n"); failures += 1
            }
        }

        // The sheets themselves — `content` is exposed on both views precisely because
        // ImageRenderer draws a ScrollView's contents empty.
        capture(PawpetItemCatalogView(onClose: {}).content.frame(width: 430)
            .background(Color(white: 0.11)), name: "itemcatalog", bare: true)
        capture(HiddenAchievementsView(onClose: {}).content.frame(width: 430)
            .background(Color(white: 0.11)), name: "achievements", bare: true)
        capture(PawpetGalleryView().frame(width: 360), name: "gallerybar")
        // A few rows at full size — the tall catalog capture is only good for checking that it
        // renders at all, not for reading it.
        capture(itemCatalogSampler(), name: "itemsample", bare: true)
        // The magnified state, forced open — a synthetic mouse-moved event needs an Accessibility
        // grant this debug binary doesn't have, so hover can't be driven from outside.
        capture(hoveredCatalogRows(), name: "itemhover", bare: true)

        write(failures == 0 ? "\nITEMS OK\n" : "\nITEMS \(failures) FAILURES\n")
        exit(failures == 0 ? 0 : 1)
    }

    /// Hosts the catalog in a plain window so the real sheet can be screenshotted with its own
    /// chrome — `ImageRenderer` draws a `ScrollView`'s contents empty.
    ///
    /// Hovering can't be driven from here: posting a synthetic mouse-moved event needs an
    /// Accessibility grant this binary doesn't have (verified — `NSEvent.mouseLocation` never
    /// moved). `forcedHover` covers the magnified state instead.
    @MainActor
    static func openItemCatalogWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let hosting = NSHostingController(rootView: PawpetItemCatalogView(onClose: {}))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Item catalog"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 430, height: 540))
        window.center()
        window.makeKeyAndOrderFront(nil)
        itemCatalogWindow = window
        write("ITEM WINDOW OPEN\n")
    }

    @MainActor private static var itemCatalogWindow: NSWindow?

    /// The first four rows with the second one magnified, to check that the enlarged cat lands
    /// above its neighbours instead of behind them.
    @MainActor
    private static func hoveredCatalogRows() -> some View {
        let group = PawpetItemCatalog.groups[0]
        let coat = PawpetItemCatalog.groups[PawpetItemCatalog.groups.count - 1]
        let view = PawpetItemCatalogView(onClose: {}, forcedHover: group.items[1].id)
        // Two groups, not the whole sheet: the full thing is 4,600pt tall and unreadable at once.
        return VStack(alignment: .leading, spacing: 14) {
            view.groupCard(group)
            view.groupCard(coat)
        }
        .padding(14).frame(width: 430).background(Color(white: 0.11))
    }

    /// One row from each axis, at the size they appear in the sheet.
    @MainActor
    private static func itemCatalogSampler() -> some View {
        let picks = PawpetItemCatalog.groups.map { ($0.title, $0.items[0]) }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(picks.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 9) {
                    PawpetView(summary: DailySummary(day: "2025-03-14"), size: 46,
                               traitsOverride: pair.1.preview ?? PawpetItemCatalog.baseCat)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pair.0) · \(pair.1.name)").font(.system(size: 11, weight: .medium))
                        Text(pair.1.condition).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
            }
        }
        .padding(14)
        .frame(width: 430)
        .background(Color(white: 0.11))
    }

    /// One day per hidden achievement, built to sit just past its threshold.
    @MainActor
    private static func hiddenAchievementFixtures() -> [(AchievementID, DailySummary)] {
        func day(_ configure: (inout DailySummary) -> Void) -> DailySummary {
            var summary = DailySummary(day: "2026-01-01")
            configure(&summary)
            return summary
        }
        return [
            (.witchingHour, day { s in
                var minutes = [Int](repeating: 0, count: 1440)
                minutes[200] = 5           // 03:20
                s.activityPerMinute = minutes
            }),
            (.oneHandedWonder, day { $0.totalKeyPresses = 2_000; $0.leftHandPercent = 78 }),
            (.tunnelVision, day { $0.appConcentration = 96; $0.activeSeconds = 4 * 3600 }),
            (.stormMinute, day { $0.busiestMinuteCount = 400 }),
            (.lidFlipper, day { $0.lidOpenCount = 10 }),
            (.fullyIndependent, day { $0.secondsOnBattery = 8 * 3600; $0.chargerConnectCount = 0 }),
            (.perfectBalance, day { $0.scrollScreens = 120; $0.scrollUpPoints = 5_000; $0.scrollDownPoints = 5_100 }),
            (.fullKeyboard, day { $0.distinctKeysUsed = 60 }),
            (.quietKeys, day { $0.activeSeconds = 4 * 3600; $0.totalKeyPresses = 3_000; $0.totalClicks = 40 })
        ]
    }

    /// Screenshots the Settings window itself. `ImageRenderer` renders `TabView` as a placeholder,
    /// so the tab bar can only be inspected on a real window.
    @MainActor
    static func captureSettingsWindow() {
        guard let window = NSApp.windows.first(where: { $0.title.contains("설정") || $0.title.contains("Settings") })
                ?? NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) })
        else { write("SETTINGS WINDOW NOT FOUND\n"); exit(1) }
        // Reproduce the reported regression: writing a setting is exactly what a toggle does, and
        // it used to rebuild the TabView and snap the user back to the General pane.
        if ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS_POKE"] != nil {
            var settings = ActivityCenter.shared.settings
            // Not `showDockIcon`: that one changes the activation policy, which reorders windows
            // and would make the screenshot below capture whatever ends up in front.
            settings.hudShowsSessionKeys.toggle()
            ActivityCenter.shared.updateSettings(settings)
            settings.hudShowsSessionKeys.toggle()
            ActivityCenter.shared.updateSettings(settings)
            write("POKED settings\n")
        }
        // Captured by window id, not by screen rect: a rect grabs whatever happens to be in
        // front, which silently produced a screenshot of an unrelated app the first time.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", "-l", String(window.windowNumber),
                          ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS_SHOT"] ?? "/tmp/pawprint_settings.png"]
        try? task.run()
        task.waitUntilExit()
        write("SETTINGS SHOT window \(window.windowNumber) \(window.title)\n")
        exit(0)
    }

    // MARK: - Session accounting (PAWPRINT_SESSIONS)

    /// Checks the arithmetic behind active time and typing speed.
    ///
    /// These are the numbers the whole app is about, and every one of them fails silently: a lost
    /// session, a session credited to the wrong day and an average over the wrong denominator all
    /// produce a plausible figure that is simply wrong.
    @MainActor
    static func probeSessionAccounting() {
        var failures = 0

        func check(_ label: String, _ condition: Bool, _ detail: String = "") {
            write("\(condition ? "ok  " : "FAIL") \(label)\(detail.isEmpty ? "" : "  — " + detail)\n")
            if !condition { failures += 1 }
        }

        // Day boundaries, which every split depends on.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = .current
        func at(_ text: String) -> Date { formatter.date(from: text)! }

        for (hour, instant, expected) in [(0, "2026-03-10 23:30", "2026-03-11 00:00"),
                                          (0, "2026-03-10 00:30", "2026-03-11 00:00"),
                                          (4, "2026-03-10 23:30", "2026-03-11 04:00"),
                                          (4, "2026-03-10 02:30", "2026-03-10 04:00")] {
            let got = DayKey.nextDayStart(after: at(instant), dayStartHour: hour)
            check("nextDayStart(\(instant), start \(hour)h)", got == at(expected),
                  "got \(formatter.string(from: got)), want \(expected)")
        }

        // A session must land on the day it was actually spent.
        let boundary = DayKey.nextDayStart(after: at("2026-03-10 23:00"), dayStartHour: 0)
        check("boundary splits a 23:00-01:00 session in two",
              boundary > at("2026-03-10 23:00") && boundary < at("2026-03-11 01:00"))

        // Average typing speed: 500 characters typed across 10 minutes, inside an hour of
        // otherwise mouse-driven work. Over active time that reads 1.7 WPM; over typing time, 10.
        var raw = DailyRawCounters(day: "2026-03-10")
        raw.characterKeyPresses = 500
        raw.activeSeconds = 3600
        for minute in 0..<10 { raw.charKeysPerMinute[minute] = 50 }
        let typed = StatsEngine.summary(for: raw).avgWPM
        write(String(format: "avgWPM over typing time = %.1f (over active time it was %.1f)\n",
                     typed, (500.0 / 5) / 60.0))
        check("avgWPM uses typing time", abs(typed - 10) < 0.01)

        // Old records have no per-minute data and must still produce their previous figure rather
        // than zero.
        var legacy = DailyRawCounters(day: "2026-03-09")
        legacy.characterKeyPresses = 600
        legacy.activeSeconds = 3600
        legacy.charKeysPerMinute = []
        let fallback = StatsEngine.summary(for: legacy).avgWPM
        check("legacy records fall back", abs(fallback - 2) < 0.01,
              String(format: "%.2f", fallback))

        write(failures == 0 ? "\nSESSIONS OK\n" : "\nSESSIONS \(failures) FAILURES\n")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Announcements (PAWPRINT_NOTICE)

    /// Exercises the notice pipeline end to end: decode, version targeting, language selection,
    /// and the dismissal rule — which is the part worth guarding, because "reading it dismisses
    /// it" is the easy mistake and would silently defeat the whole feature.
    @MainActor
    static func probeAnnouncements() {
        var failures = 0
        let path = ProcessInfo.processInfo.environment["PAWPRINT_NOTICE"] ?? "docs/announcements.json"

        guard let data = FileManager.default.contents(atPath: path),
              let feed = try? JSONDecoder().decode(AnnouncementFeed.self, from: data) else {
            write("FAIL cannot decode \(path)\n"); exit(1)
        }
        write("decoded \(feed.announcements.count) announcement(s) from \(path)\n\n")

        for item in feed.announcements {
            write("[\(item.id)] severity=\(item.severity ?? "info") published=\(item.publishedAt ?? "-")\n")
            for language in ["ko", "en"] {
                let title = item.title(for: language)
                let body = item.body(for: language)
                write("  \(language): \(title)  (\(body.count) chars)\n")
                if title.isEmpty { write("FAIL empty title for \(language)\n"); failures += 1 }
                if body.count < 40 { write("FAIL body too short for \(language)\n"); failures += 1 }
            }
            // A notice nobody can see is worse than none.
            if !item.applies(to: UpdateChecker.shared.currentVersion) {
                write("FAIL does not apply to the current version\n"); failures += 1
            }
        }

        // Version bounds.
        var bounded = feed.announcements[0]
        bounded.minVersion = "0.3.0"
        bounded.maxVersion = "0.3.9"
        // 0.3.10 is *above* 0.3.9, so an upper bound of 0.3.9 excludes it. Lexicographic
        // comparison would order it below and wrongly let it through.
        for (version, expected) in [("0.2.9", false), ("0.3.0", true), ("0.3.5", true),
                                    ("0.3.9", true), ("0.3.10", false), ("0.4.0", false)] {
            if bounded.applies(to: version) != expected {
                write("FAIL version \(version) should be \(expected)\n"); failures += 1
            }
        }
        // String comparison would put 0.10.0 before 0.9.0.
        if Announcement.compareVersions("0.10.0", "0.9.0") <= 0 {
            write("FAIL version comparison is lexicographic\n"); failures += 1
        }

        // Dismissal: only the explicit action hides a notice, and it survives a settings reload.
        let center = AnnouncementCenter.shared
        var settings = ActivityCenter.shared.settings
        let restore = settings
        settings.dismissedAnnouncements = []
        ActivityCenter.shared.updateSettings(settings)
        center.announcements = feed.announcements

        guard let shown = center.current else {
            write("FAIL nothing shown with an empty dismissed list\n")
            ActivityCenter.shared.updateSettings(restore)
            exit(1)
        }
        write("\nshowing: \(shown.id)\n")
        center.dismiss(shown)
        if center.current?.id == shown.id {
            write("FAIL still showing after dismiss\n"); failures += 1
        } else {
            write("hidden after dismiss: ok\n")
        }
        if !ActivityCenter.shared.settings.dismissedAnnouncements.contains(shown.id) {
            write("FAIL dismissal was not persisted\n"); failures += 1
        } else {
            write("dismissal persisted: ok\n")
        }
        ActivityCenter.shared.updateSettings(restore)

        // Rotation. With several undismissed notices every one has to come round; showing only
        // the newest meant the ones behind it waited forever, since dismissal is deliberate.
        do {
            var settings = ActivityCenter.shared.settings
            settings.dismissedAnnouncements = []
            ActivityCenter.shared.updateSettings(settings)

            func notice(_ id: String, _ day: String) -> Announcement {
                Announcement(id: id, severity: "info", publishedAt: day,
                             title: ["en": id], body: ["en": String(repeating: "x", count: 50)])
            }
            center.announcements = [notice("a", "2026-07-03"),
                                    notice("b", "2026-07-02"),
                                    notice("c", "2026-07-01")]
            center.resetRotationForTesting()

            var seen: [String] = []
            for _ in 0..<6 {
                seen.append(center.current?.id ?? "nil")
                center.advance()
            }
            write("\nrotation over 3: \(seen.joined(separator: " -> "))\n")
            if Set(seen).count != 3 {
                write("FAIL rotation does not reach every notice\n"); failures += 1
            }
            if seen.prefix(3) != ["a", "b", "c"] {
                write("FAIL rotation order is not newest-first\n"); failures += 1
            }

            // Dismissing mid-rotation must leave a valid selection, not a stale index.
            center.resetRotationForTesting()
            center.advance()
            guard let middle = center.current else {
                write("FAIL nothing selected\n"); failures += 1; return
            }
            center.dismiss(middle)
            let after = center.current?.id ?? "nil"
            write("dismissed \(middle.id) -> now \(after), \(center.visibleCount) left\n")
            if center.visibleCount != 2 || after == middle.id {
                write("FAIL dismissal left a bad selection\n"); failures += 1
            }

            // One notice must not rotate at all.
            center.announcements = [notice("solo", "2026-07-01")]
            settings.dismissedAnnouncements = []
            ActivityCenter.shared.updateSettings(settings)
            center.resetRotationForTesting()
            center.advance()
            if center.current?.id != "solo" {
                write("FAIL a single notice moved\n"); failures += 1
            } else {
                write("single notice stays put: ok\n")
            }
        }

        // Restore so the banner has something to draw, then snapshot both surfaces.
        center.announcements = feed.announcements
        var clean = ActivityCenter.shared.settings
        clean.dismissedAnnouncements = []
        ActivityCenter.shared.updateSettings(clean)
        capture(AnnouncementBanner().frame(width: 360).padding(10)
            .background(Color(white: 0.12)), name: "noticebanner", bare: true)
        if let item = feed.announcements.first {
            capture(announcementDetailPreview(item), name: "noticedetail", bare: true)
        }
        ActivityCenter.shared.updateSettings(restore)

        // The published feed, over the network, exactly as the app fetches it. Local decoding
        // passing says nothing about whether the workflow is actually publishing anything.
        //
        // Done in a Task that owns the rest of the probe rather than by blocking on a semaphore:
        // waiting on the main thread for a `@MainActor` Task deadlocks, because the Task needs
        // the thread being blocked. (It did, and reported an empty feed that was actually fine.)
        guard ProcessInfo.processInfo.environment["PAWPRINT_NOTICE_LIVE"] != nil else {
            finishAnnouncementProbe(failures)
            return
        }
        Task { @MainActor in
            var failures = failures
            AnnouncementCenter.shared.announcements = []
            await AnnouncementCenter.shared.refresh()
            let live = AnnouncementCenter.shared.announcements
            write("\nlive feed: \(live.count) announcement(s)\n")
            for item in live { write("  \(item.id)  \(item.title(for: "ko"))\n") }
            if live.isEmpty { write("FAIL live feed is empty\n"); failures += 1 }
            center.announcements = feed.announcements
            finishAnnouncementProbe(failures)
        }
    }

    @MainActor
    private static func finishAnnouncementProbe(_ failures: Int) {
        write(failures == 0 ? "\nNOTICE OK\n" : "\nNOTICE \(failures) FAILURES\n")
        exit(failures == 0 ? 0 : 1)
    }

    /// The detail sheet's contents. `AnnouncementDetailView` is private to its file and lives in a
    /// `.sheet`, which `ImageRenderer` will not draw, so this mirrors its layout for inspection.
    @MainActor
    private static func announcementDetailPreview(_ item: Announcement) -> some View {
        let language = LocalizationManager.shared.languageCode
        return VStack(alignment: .leading, spacing: 10) {
            Text(item.title(for: language)).font(.headline)
            Text(item.body(for: language))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Text(L10n.t("announcement.dontShowAgain"))
                    .font(.callout)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                Text(L10n.t("announcement.close"))
                    .font(.callout)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.5)))
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(Color(white: 0.12))
    }

    // MARK: - Language resolution (PAWPRINT_LANG_PROBE)

    /// Reports which pack the app starts on for the current system language.
    ///
    /// Run with `-AppleLanguages "(fr)"` and friends to check the unlisted-language path: the
    /// answer has to be English, not the base pack. Reasoning about it is not enough — the base
    /// pack being Korean made "no pack for your language" and "fall back to Korean" the same code
    /// path, and it read as correct right up until you tried it.
    @MainActor
    static func probeLanguageResolution() {
        write("preferredLanguages = \(Locale.preferredLanguages.prefix(4).joined(separator: ", "))\n")
        write("systemPreferredCode = \(LocalizationManager.systemPreferredCode() ?? "nil")\n")
        write("defaultCode         = \(LocalizationManager.defaultCode)\n")
        write("active pack         = \(LocalizationManager.shared.languageCode)\n")

        // A string only the packs can answer, to prove which table is really in use.
        let sample = L10n.t("settingsRootView.aef1a1e7")
        write("sample string       = \(sample)\n")

        let expected = ProcessInfo.processInfo.environment["PAWPRINT_LANG_EXPECT"]
        if let expected, LocalizationManager.shared.languageCode != expected {
            write("FAIL expected \(expected), got \(LocalizationManager.shared.languageCode)\n")
            exit(1)
        }
        write("LANG OK\n")
        exit(0)
    }

    // MARK: - Chaos index distribution (PAWPRINT_CHAOS)

    /// Prints the chaos index for every recorded day, plus a few synthetic ones.
    ///
    /// The failure being guarded against is silent: an index that reads 100 for everybody is
    /// indistinguishable from a working one until you look at the spread.
    @MainActor
    static func probeChaosIndex() {
        let raws = PawprintStore.shared.allDays()
        let dayStart = ActivityCenter.shared.settings.dayStartHour
        let days = raws.map { StatsEngine.summary(for: $0, recentDays: [], dayStartHour: dayStart) }
        write("recorded days: \(days.count)\n\n")
        var pinned = 0
        for day in days.sorted(by: { $0.day < $1.day }) {
            let value = day.chaosIndex
            if value >= 99.5 { pinned += 1 }
            let bar = String(repeating: "#", count: Int(value / 4))
            write(String(format: "  %@  %5.1f  %@  (switches %d, short %d)\n",
                         day.day, value, bar, day.totalAppSwitches, day.shortDwellCount))
        }
        if !days.isEmpty {
            let values = days.map(\.chaosIndex)
            write(String(format: "\nmin %.1f  max %.1f  mean %.1f  pinned-at-100 %d/%d\n",
                         values.min() ?? 0, values.max() ?? 0,
                         values.reduce(0, +) / Double(values.count), pinned, days.count))
        }
        // A long but unremarkable day must not score high — that is the case that used to pin.
        if pinned > days.count / 3 && days.count >= 3 {
            write("\nFAIL most days are pinned at 100\n")
            exit(1)
        }
        write("\nCHAOS OK\n")
        exit(0)
    }

    // MARK: - Keyboard event delivery (PAWPRINT_KEYS)

    /// Reports which of the two keyboard monitors is actually receiving events.
    ///
    /// This is the only way to tell the reported failure apart from an idle keyboard: both look
    /// like "no letters counted". Type for the duration and read the two counters — modifiers
    /// climbing while keys stay at zero is a dead `.keyDown` registration, not a quiet user.
    @MainActor
    static func probeKeyboardDelivery() {
        write("AXIsProcessTrusted       = \(AXIsProcessTrusted())\n")
        write("IOHIDCheckAccess(listen) = \(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue)"
              + "  (0 granted / 1 denied / 2 unknown)\n")

        let monitor = KeyboardMonitor()
        monitor.start()
        let seconds = Int(ProcessInfo.processInfo.environment["PAWPRINT_KEYS"].flatMap { Int($0) } ?? 15)
        write("\nType anything for \(seconds)s — including plain letters...\n")

        var elapsed = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            MainActor.assumeIsolated {
                elapsed += 1
                write("  \(elapsed)s  keyDown=\(monitor.keyDownsSeen)  flagsChanged=\(monitor.flagsSeen)\n")
                guard elapsed >= seconds else { return }
                timer.invalidate()
                write("\nkeyDown total      = \(monitor.keyDownsSeen)\n")
                write("flagsChanged total = \(monitor.flagsSeen)\n")
                if monitor.looksStalled {
                    write("\nSTALLED — modifiers arrive, key events do not."
                          + " Input Monitoring was granted after the monitor was registered.\n")
                    exit(1)
                }
                if monitor.keyDownsSeen == 0 && monitor.flagsSeen == 0 {
                    write("\nNOTHING RECEIVED — no typing, or neither permission is live.\n")
                    exit(2)
                }
                write("\nKEYS OK — both monitors are delivering.\n")
                exit(0)
            }
        }
    }

    // MARK: - Record reward size (PAWPRINT_REWARDS)

    /// Guards the size of the personal-best bonus, which stays invisible until a grade looks wrong.
    @MainActor
    static func probeRecordRewards() {
        var failures = 0

        // Setting a record must be a small bonus, not a free grade. It used to force the
        //    prismatic frame — 32 of 100 points — plus the sparkle expression, so a quiet day
        //    that happened to nudge one counter jumped straight to grade S.
        var day = DailySummary(day: "2026-02-10")
        day.totalKeyPresses = 400
        day.activeSeconds = 3_600
        let plain = PawpetTraits(day: day.day, summary: day, setARecord: false)
        let record = PawpetTraits(day: day.day, summary: day, setARecord: true)
        let bonus = record.rarity - plain.rarity
        write("record bonus \(plain.rarity) -> \(record.rarity)  (+\(bonus))\n")
        write("  frame \(plain.frame) -> \(record.frame), head \(plain.headwear) -> \(record.headwear)\n")
        write("  expr \(plain.expression) -> \(record.expression), float \(plain.floaters) -> \(record.floaters)\n")
        if bonus > 10 { write("FAIL record bonus \(bonus) is too large\n"); failures += 1 }
        if bonus <= 0 { write("FAIL record earns nothing\n"); failures += 1 }
        if record.frame != plain.frame {
            write("FAIL a record changed the frame\n"); failures += 1
        }
        if record.rarityGrade != plain.rarityGrade {
            write("FAIL a record changed the grade \(plain.rarityGrade) -> \(record.rarityGrade)\n")
            failures += 1
        }

        write(failures == 0 ? "\nREWARDS OK\n" : "\nREWARDS \(failures) FAILURES\n")
        exit(failures == 0 ? 0 : 1)
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
                                              streakDays: 40, setARecord: celebrating)
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
                                   traitsOverride: PawpetTraits(day: entry.0.day, summary: entry.0,
                                                                streakDays: 40, setARecord: entry.1))
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
                    let t = PawpetTraits(day: s.day, summary: s, streakDays: 40, setARecord: recipe.celebrating)
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
                                   traitsOverride: PawpetTraits(day: entry.0.day, summary: entry.0,
                                                                streakDays: 40, setARecord: entry.1))
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
