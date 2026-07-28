import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItemController = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPolicy()
        TrackingCoordinator.shared.start()
        MenuBarIconAnimator.shared.start()
        statusItemController.install()

        // Re-arm the daily recap on every launch: the scheduled body carries the day's numbers,
        // so it needs refreshing rather than surviving from a previous run.
        let settings = ActivityCenter.shared.settings
        if settings.dailySummaryEnabled {
            Task { @MainActor in
                await NotificationManager.shared.scheduleDailySummary(
                    hour: settings.dailySummaryHour,
                    minute: settings.dailySummaryMinute,
                    summary: ActivityCenter.shared.todaySummary
                )
            }
        }
        // First run: nothing works without Accessibility + Input Monitoring, and macOS shows its
        // own prompts exactly once. Walk the user through it rather than reporting zeros forever.
        if !settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingWindowController.shared.present()
            }
        }

        UpdateChecker.shared.startPeriodicChecks(settings: settings)

        // End-to-end exercise of the update pipeline: check → download → ditto → signature
        // verification → swap. There is no other way to prove the install path works, since it
        // replaces the running bundle and can't be unit-tested in-process.
        if ProcessInfo.processInfo.environment["PAWPRINT_RECORD_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeRecordCelebration() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeAutomaticUpdate() }
        }

        if let feed = ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_TEST"] {
            Task { @MainActor in DebugSnapshot.runUpdateFlow(feed: feed) }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_DMG_BG"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderDMGBackground(); NSApp.terminate(nil)
            }
        }

        // Presets the icon style and screenshots the real menu bar, which is the only place the
        // status item is actually drawn — everything else is a render of the same image.
        if let style = ProcessInfo.processInfo.environment["PAWPRINT_ICON_STYLE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                var updated = ActivityCenter.shared.settings
                updated.menuBarIcon = style.hasPrefix("cat") ? .cat : .paw
                ActivityCenter.shared.updateSettings(updated)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // "catsleep" drives the idle path — what the icon shows whenever nobody is at
                    // the keyboard. Forced here rather than earlier because the controller's pace
                    // timer re-checks real activity every 1.5s and would wake it straight back up
                    // (it did: the first attempt screenshotted an awake cat).
                    if style.hasSuffix("sleep") {
                        MenuBarIconAnimator.shared.updatePace(liveWPM: 0, isRecording: true,
                                                              secondsSinceActivity: 600)
                    }
                    // Ask the status item where it ended up; its x depends on what else is in the
                    // menu bar, and a guessed rect came back as a strip of pure black.
                    let frame = self.statusItemController.buttonScreenFrame
                        ?? NSRect(x: 1200, y: 0, width: 120, height: 24)
                    let screenHeight = NSScreen.main?.frame.height ?? 900
                    let pad: CGFloat = 30
                    let region = "\(Int(frame.minX - pad)),\(Int(screenHeight - frame.maxY))," +
                                 "\(Int(frame.width + pad * 2)),\(Int(frame.height))"
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    task.arguments = ["-x", "-R", region,
                                      "/tmp/pawprint_menubar_\(style).png"]
                    try? task.run()
                    task.waitUntilExit()
                    FileHandle.standardError.write("MENUBAR SHOT \(style)\n".data(using: .utf8)!)
                    exit(0)
                }
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_MENUCAT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderMenuBarCatSheet(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SOCIAL"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderSocialCard(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_BANNER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderBanner(); NSApp.terminate(nil)
            }
        }

        // Opens Settings so its window can be screenshotted; SwiftUI's TabView renders as a
        // placeholder in ImageRenderer, so a real window is the only way to check the tab bar.
        if let language = ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                var updated = ActivityCenter.shared.settings
                switch language {
                case "en": updated.language = .english
                case "ko": updated.language = .korean
                // Anything else means "leave it on system", so the resolved default can be seen.
                default: updated.language = .system
                }
                ActivityCenter.shared.updateSettings(updated)
                if ProcessInfo.processInfo.environment["PAWPRINT_FORCE_STALL"] != nil {
                    PermissionsManager.shared.setKeyboardEventsStalled(true)
                }
                SettingsOpener.open()
                if ProcessInfo.processInfo.environment["PAWPRINT_SETTINGS_SHOT"] != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        DebugSnapshot.captureSettingsWindow()
                    }
                }
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SWITCH"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { DebugSnapshot.probeLanguageSwitch() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_CLIPBOARD"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { DebugSnapshot.probeClipboard() }
        }

        // Opens the item catalog in a real window so the hover magnifier can be driven with a
        // synthetic mouse move and screenshotted — ImageRenderer has no pointer.
        if ProcessInfo.processInfo.environment["PAWPRINT_ITEMS_WINDOW"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.openItemCatalogWindow() }
        }

        // Seeds a throwaway history and photographs the real app for the README.
        if ProcessInfo.processInfo.environment["PAWPRINT_SEED_DEMO"] != nil {
            DemoData.generate()
            ActivityCenter.shared.reloadAfterExternalChange()
        }
        if let shotLanguage = ProcessInfo.processInfo.environment["PAWPRINT_SHOT_LANG"] {
            var updated = ActivityCenter.shared.settings
            updated.language = shotLanguage == "ko" ? .korean : .english
            ActivityCenter.shared.updateSettings(updated)
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_GIF"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.renderMenuBarGIFs() }
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_SHOTS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                DebugSnapshot.captureReadmeShots(controller: self.statusItemController)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_STREAK"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeStreaks() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SESSIONS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeSessionAccounting() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_NOTICE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeAnnouncements() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_LANG_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeLanguageResolution() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_CHAOS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { DebugSnapshot.probeChaosIndex() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_KEYS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { DebugSnapshot.probeKeyboardDelivery() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_REWARDS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeRecordRewards() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_ITEMS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeItemCatalog() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_L10N"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.auditLocalization() }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_WALL"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderCatWall(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_SHOWCASE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderShowcase(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_TITLES"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                DebugSnapshot.runTitleReport(); NSApp.terminate(nil)
            }
        }

        if ProcessInfo.processInfo.environment["PAWPRINT_PROBE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { DebugSnapshot.probeSettings() }
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_PAWPETS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DebugSnapshot.renderPawpetSheet(); NSApp.terminate(nil)
            }
        }
        if ProcessInfo.processInfo.environment["PAWPRINT_SNAPSHOT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { DebugSnapshot.run(); NSApp.terminate(nil) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController.remove()
        MenuBarIconAnimator.shared.stop()
        TrackingCoordinator.shared.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applyDockIconPolicy() {
        NSApp.setActivationPolicy(ActivityCenter.shared.settings.showDockIcon ? .regular : .accessory)
    }
}
