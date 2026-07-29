import Foundation

/// Derives "focus sessions": stretches where the user stayed active in one primary app,
/// tolerating brief trips elsewhere (checking a message) without breaking the streak.
///
/// Driven by the *current frontmost app plus the last input time*, sampled on a timer — not by
/// app-activation events alone. An earlier version only advanced its "still on the primary app"
/// timestamp when an activation event arrived, which meant uninterrupted work in a single app
/// produced no events, looked like an absence, and ended the session at zero length. Sitting
/// still in one app is precisely what this is supposed to detect, so presence must be polled.
final package class FocusEngine {
    /// How long the user may be in another app before the focus session is considered broken.
    package var graceSeconds: TimeInterval = 45
    /// No input for this long ends the session — an idle Mac parked on one app isn't focus.
    package var idleGraceSeconds: TimeInterval = 120
    package var focusThresholdSeconds: TimeInterval = 5 * 60

    private var primaryBundleID: String?
    private var primaryAppName: String?
    private var focusStart: Date?
    /// Last moment we positively knew the user was working in the primary app.
    private var lastOnPrimaryAt: Date?
    private var interruptionCounts: [String: Int] = [:]

    /// When the frontmost app first became something other than the primary, and what it was.
    /// Used so a session that follows an interruption starts when the user actually arrived,
    /// not when the grace period happened to expire.
    private var awaySince: Date?
    private var awayBundleID: String?
    private var awayAppName: String?

    /// A `package class` gets an internal default initializer, which the application target
    /// cannot reach. Nothing is configured here — the three thresholds above have defaults and
    /// are set by the caller after construction, exactly as before.
    package init() {}

    package typealias Emit = (FocusSessionRecord, [String: Int]) -> Void

    /// Called whenever a new app comes to the front. Counts the interruption; the actual
    /// start/stop bookkeeping is shared with `update`.
    package func appActivated(bundleID: String, name: String, at date: Date, lastActivityAt: Date?, emit: Emit) {
        if let primary = primaryBundleID, bundleID != primary {
            interruptionCounts[name, default: 0] += 1
        }
        update(now: date, frontmostBundleID: bundleID, frontmostAppName: name, lastActivityAt: lastActivityAt, emit: emit)
    }

    /// Polls the current state. Safe (and expected) to call on a timer.
    package func update(
        now: Date,
        frontmostBundleID: String?,
        frontmostAppName: String?,
        lastActivityAt: Date?,
        emit: Emit
    ) {
        let isPresent = lastActivityAt.map { now.timeIntervalSince($0) <= idleGraceSeconds } ?? false

        guard isPresent, let frontmostBundleID, let frontmostAppName else {
            // Went idle: close out the session at the last moment of real presence.
            if let start = focusStart, let lastOnPrimary = lastOnPrimaryAt {
                let end = min(lastOnPrimary, lastActivityAt ?? lastOnPrimary)
                finalize(start: start, end: end, emit: emit)
            }
            clear()
            return
        }

        guard let primary = primaryBundleID, let start = focusStart, let lastOnPrimary = lastOnPrimaryAt else {
            startCandidate(bundleID: frontmostBundleID, name: frontmostAppName, at: now)
            return
        }

        if frontmostBundleID == primary {
            // Still working in the primary app — extend the session.
            lastOnPrimaryAt = now
            awaySince = nil
            awayBundleID = nil
            awayAppName = nil
            return
        }

        // In a different app. Remember when the detour began.
        if awaySince == nil || awayBundleID != frontmostBundleID {
            awaySince = now
            awayBundleID = frontmostBundleID
            awayAppName = frontmostAppName
        }

        if now.timeIntervalSince(lastOnPrimary) > graceSeconds {
            finalize(start: start, end: lastOnPrimary, emit: emit)
            // The new session starts when the user actually arrived in the new app.
            startCandidate(
                bundleID: frontmostBundleID,
                name: frontmostAppName,
                at: awaySince ?? now
            )
        }
    }

    package func reset() {
        clear()
    }

    private func clear() {
        primaryBundleID = nil
        primaryAppName = nil
        focusStart = nil
        lastOnPrimaryAt = nil
        interruptionCounts = [:]
        awaySince = nil
        awayBundleID = nil
        awayAppName = nil
    }

    private func startCandidate(bundleID: String, name: String, at date: Date) {
        primaryBundleID = bundleID
        primaryAppName = name
        focusStart = date
        lastOnPrimaryAt = date
        interruptionCounts = [:]
        awaySince = nil
        awayBundleID = nil
        awayAppName = nil
    }

    private func finalize(start: Date, end: Date, emit: Emit) {
        let duration = end.timeIntervalSince(start)
        guard duration >= focusThresholdSeconds else { return }
        emit(
            FocusSessionRecord(
                start: start,
                end: end,
                primaryApp: primaryAppName ?? primaryBundleID ?? "",
                interruptionCount: interruptionCounts.values.reduce(0, +)
            ),
            interruptionCounts
        )
    }
}
