import AppKit

/// Observes app activation/launch/termination via `NSWorkspace`. Only the bundle identifier
/// and localized app name are read — never window titles, document names, or URLs — so no
/// app *content* is ever visible to Pawprint, only which app was in front and for how long.
final class AppUsageMonitor {
    private var activationObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    private var currentBundleID: String?
    private var currentAppName: String?
    private var currentSessionStart: Date?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        activationObserver = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleActivation(note)
        }
        launchObserver = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleLaunch(note)
        }
        terminateObserver = nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleTerminate(note)
        }

        if let app = NSWorkspace.shared.frontmostApplication {
            let bundleID = app.bundleIdentifier ?? "unknown.\(app.processIdentifier)"
            let name = app.localizedName ?? bundleID
            let now = Date()
            currentBundleID = bundleID
            currentAppName = name
            currentSessionStart = now
            ActivityCenter.shared.appDidActivate(bundleID: bundleID, name: name, at: now)
        }
    }

    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in [activationObserver, launchObserver, terminateObserver].compactMap({ $0 }) {
            nc.removeObserver(observer)
        }
        activationObserver = nil
        launchObserver = nil
        terminateObserver = nil
        closeCurrentSession(at: Date())
    }

    private func handleActivation(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let bundleID = app.bundleIdentifier ?? "unknown.\(app.processIdentifier)"
        let name = app.localizedName ?? bundleID
        let now = Date()

        closeCurrentSession(at: now)

        currentBundleID = bundleID
        currentAppName = name
        currentSessionStart = now

        ActivityCenter.shared.appDidActivate(bundleID: bundleID, name: name, at: now)
    }

    private func closeCurrentSession(at end: Date) {
        guard let bundleID = currentBundleID, let name = currentAppName, let start = currentSessionStart, end > start else { return }
        let session = AppSessionRecord(bundleID: bundleID, appName: name, start: start, end: end)
        ActivityCenter.shared.recordAppSession(session)
    }

    private func handleLaunch(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }
        ActivityCenter.shared.recordAppLaunch(bundleID: bundleID)
    }

    private func handleTerminate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }
        ActivityCenter.shared.recordAppTerminate(bundleID: bundleID)
    }
}
