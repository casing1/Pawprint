import Foundation

struct AdventureSnapshotConfiguration: Equatable {
    let outputPath: String
    let databasePath: String
}

enum AdventureSnapshotHarnessError: Error, Equatable, CustomStringConvertible {
    case missingDatabase
    case outputMatchesDatabase

    var description: String {
        switch self {
        case .missingDatabase:
            return "PAWPRINT_ADVENTURE_SHOT requires a non-empty PAWPRINT_DB"
        case .outputMatchesDatabase:
            return "PAWPRINT_ADVENTURE_SHOT must not overwrite PAWPRINT_DB"
        }
    }
}

/// Preflights the adventure visual-regression hook before any singleton can open the real store.
///
/// Normal app launches have no `PAWPRINT_ADVENTURE_SHOT` value and therefore bypass this entirely.
enum AdventureSnapshotHarness {
    static func configuration(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AdventureSnapshotConfiguration? {
        guard let outputPath = nonEmpty(environment["PAWPRINT_ADVENTURE_SHOT"]) else {
            return nil
        }
        guard let databasePath = nonEmpty(environment["PAWPRINT_DB"]) else {
            throw AdventureSnapshotHarnessError.missingDatabase
        }

        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        let databaseURL = URL(fileURLWithPath: databasePath).standardizedFileURL
        guard outputURL != databaseURL else {
            throw AdventureSnapshotHarnessError.outputMatchesDatabase
        }

        return AdventureSnapshotConfiguration(
            outputPath: outputPath,
            databasePath: databasePath
        )
    }

    static func shouldAutorun(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard environment["PAWPRINT_ADVENTURE_AUTORUN"] != nil else { return false }
        do {
            return try configuration(environment: environment) != nil
        } catch {
            return false
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
