import Foundation
import os

/// What went wrong in storage, and whether anyone was told.
///
/// Every database call in this file used to be `try?`. A failed write returned nothing and looked
/// exactly like a successful one, so a full disk, a permissions change or a corrupt file cost the
/// user their day's records in silence — the app kept counting, the numbers kept climbing on
/// screen, and none of it reached the disk.
///
/// Two things fix that and neither is throwing from every accessor, which would push error
/// handling into a hundred SwiftUI call sites that have nothing useful to do with it: the failure
/// is *logged*, and it is *recorded here* where the interface can show it.
package enum StoreFailure: Error, Equatable {
    case couldNotOpen(String)
    case couldNotSaveDay(day: String, reason: String)
    case couldNotSaveSettings(String)
    case couldNotRead(String)
    case migrationFailed(from: Int, to: Int, reason: String)

    /// What the user is told. Deliberately short and free of SQLite's own wording, which is
    /// meaningless to anyone who did not write this file.
    package var summary: String {
        switch self {
        case .couldNotOpen: return L10n.t("storeHealth.7a3d0f21")
        case .couldNotSaveDay, .couldNotSaveSettings: return L10n.t("storeHealth.4c9e21b8")
        case .couldNotRead: return L10n.t("storeHealth.b1f27d40")
        case .migrationFailed: return L10n.t("storeHealth.e05a9c33")
        }
    }
}

/// Whether storage is working, in one place the interface can read.
package final class StoreHealth: @unchecked Sendable {
    package static let shared = StoreHealth()

    private let lock = NSLock()
    private var failure: StoreFailure?
    private var failureCount = 0

    private init() {}

    /// The most recent failure, or `nil` when everything has worked.
    package var lastFailure: StoreFailure? { lock.withLock { failure } }
    /// How many failures there have been since launch. A single blip and a disk that has been full
    /// for an hour deserve different reactions.
    package var count: Int { lock.withLock { failureCount } }

    package func record(_ failure: StoreFailure) {
        lock.withLock {
            self.failure = failure
            failureCount += 1
        }
        StoreLog.report(failure)
    }

    /// Called after a write succeeds, so a transient failure does not leave a warning on screen
    /// for the rest of the session.
    package func recordSuccess() {
        lock.withLock { failure = nil }
    }

    /// Tests share a process; a failure recorded by one must not be visible to the next.
    package func reset() {
        lock.withLock { failure = nil; failureCount = 0 }
    }
}

/// Logging for the storage layer.
///
/// Every interpolation is marked `.public` or `.private` deliberately. Day keys, counts and SQLite's
/// own messages are safe to write to the system log; a *path* is not — it contains the user's home
/// directory and therefore their name — so paths are private and redacted in anyone else's copy of
/// the log.
package enum StoreLog {
    private static let logger = Logger(subsystem: "com.pawprint.app", category: "storage")

    package static func report(_ failure: StoreFailure) {
        switch failure {
        case .couldNotOpen(let reason):
            logger.error("could not open the database: \(reason, privacy: .public)")
        case .couldNotSaveDay(let day, let reason):
            logger.error("could not save \(day, privacy: .public): \(reason, privacy: .public)")
        case .couldNotSaveSettings(let reason):
            logger.error("could not save settings: \(reason, privacy: .public)")
        case .couldNotRead(let reason):
            logger.error("could not read: \(reason, privacy: .public)")
        case .migrationFailed(let from, let to, let reason):
            logger.error("migration \(from, privacy: .public)→\(to, privacy: .public) failed: \(reason, privacy: .public)")
        }
    }

    /// A row that could not be decoded. One bad row costs that day and nothing else, which is the
    /// behaviour worth keeping — but it should not be invisible.
    package static func skippedRow(day: String) {
        logger.error("skipped an unreadable row for \(day, privacy: .public)")
    }

    package static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Paths are private: they carry the user's home directory, and therefore their name.
    package static func opened(at path: String, schema: Int) {
        logger.info("opened schema v\(schema, privacy: .public) at \(path, privacy: .private)")
    }
}
