import Foundation

/// Whether an event may be recorded at all.
///
/// Every privacy promise Pawprint makes about *when* it records lives here: paused means paused,
/// an excluded application is excluded, a switched-off category is not collected, and a handful of
/// system processes are never attributed to anyone. Concentrating that in one place was already
/// the design — the gate was enforced in exactly one method — but it was a method on a 933-line
/// `@Observable` class that also owned rollover, persistence and the statistics, so the rule could
/// not be exercised without standing the whole thing up.
///
/// A value type, computed from settings and the frontmost application. No storage, no clock, no
/// database: given the same settings and the same app it always answers the same way, which is what
/// makes "does pausing actually stop recording" a question a test can ask.
package struct RecordingPolicy {

    /// Processes that are never recorded, whatever the settings say.
    ///
    /// These are the login window, the screen saver, the password agent and their neighbours —
    /// windows that are in front precisely when someone is doing something private, and none of
    /// which is an application anybody would think of themselves as "using".
    package static let systemProcessBundleIDs: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.ScreenSaver.Engine",
        "com.apple.Spotlight",
        "com.apple.WindowManager",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.CoreServices.uiagent",
    ]

    package var settings: AppSettings
    /// Bundle identifier of the frontmost application, if there is one.
    package var frontmostBundleID: String?

    package init(settings: AppSettings, frontmostBundleID: String? = nil) {
        self.settings = settings
        self.frontmostBundleID = frontmostBundleID
    }

    /// Excluded either because the user said so, or because it is a system process.
    package func isExcluded(bundleID: String) -> Bool {
        Self.systemProcessBundleIDs.contains(bundleID)
            || settings.excludedApps.contains { $0.bundleID == bundleID }
    }

    package var isCurrentAppExcluded: Bool {
        frontmostBundleID.map(isExcluded) ?? false
    }

    /// The overall gate: recording is on, and the app in front is not one being kept out of it.
    package var isRecordingActive: Bool {
        !settings.isPaused && !isCurrentAppExcluded
    }

    package func isCategoryEnabled(_ category: CollectionCategory) -> Bool {
        switch category {
        case .keyboard: return settings.collectKeyboard
        case .mouse: return settings.collectMouse
        case .appUsage: return settings.collectAppUsage
        case .clipboard: return settings.collectClipboard
        case .sleepWake: return settings.collectSleepWake
        case .powerPeripherals: return settings.collectPowerPeripherals
        }
    }

    /// The single question every tracker asks before recording anything.
    package func allows(_ category: CollectionCategory) -> Bool {
        isRecordingActive && isCategoryEnabled(category)
    }
}
