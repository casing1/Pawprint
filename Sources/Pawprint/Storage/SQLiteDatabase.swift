import Foundation
import SQLite3

enum SQLiteError: Error, LocalizedError {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "DB open failed: \(m)"
        case .execFailed(let m): return "DB exec failed: \(m)"
        case .prepareFailed(let m): return "DB prepare failed: \(m)"
        case .stepFailed(let m): return "DB step failed: \(m)"
        }
    }
}

protocol SQLiteBindable {
    func bind(to stmt: OpaquePointer?, index: Int32)
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension String: SQLiteBindable {
    func bind(to stmt: OpaquePointer?, index: Int32) {
        sqlite3_bind_text(stmt, index, self, -1, sqliteTransient)
    }
}

extension Int: SQLiteBindable {
    func bind(to stmt: OpaquePointer?, index: Int32) {
        sqlite3_bind_int64(stmt, index, Int64(self))
    }
}

/// A minimal, hand-rolled wrapper over the C sqlite3 API (linked via the system libsqlite3 —
/// no external package dependency, so the project builds fully offline).
/// All access is serialized through `queue` since a single sqlite3 connection is not safe
/// to use concurrently from multiple threads without external synchronization.
final class SQLiteDatabase {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.pawprint.sqlite")

    init(path: String) throws {
        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) != SQLITE_OK {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw SQLiteError.openFailed(msg)
        }
        db = handle
        try? exec("PRAGMA journal_mode=WAL;")
        try? exec("PRAGMA foreign_keys=ON;")
    }

    deinit {
        sqlite3_close(db)
    }

    func exec(_ sql: String) throws {
        try queue.sync {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(errMsg)
                throw SQLiteError.execFailed(msg)
            }
        }
    }

    @discardableResult
    func run(_ sql: String, _ bindings: [SQLiteBindable] = []) throws -> Int {
        try queue.sync {
            let stmt = try prepareLocked(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, b) in bindings.enumerated() {
                b.bind(to: stmt, index: Int32(i + 1))
            }
            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
                throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
            return Int(sqlite3_changes(db))
        }
    }

    /// Runs a SELECT, invoking `rowHandler` once per result row on the caller's thread (synchronously, from the DB queue).
    func query(_ sql: String, _ bindings: [SQLiteBindable] = [], _ rowHandler: (OpaquePointer) -> Void) throws {
        try queue.sync {
            let stmt = try prepareLocked(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, b) in bindings.enumerated() {
                b.bind(to: stmt, index: Int32(i + 1))
            }
            while true {
                let rc = sqlite3_step(stmt)
                if rc == SQLITE_ROW {
                    rowHandler(stmt!)
                } else if rc == SQLITE_DONE {
                    break
                } else {
                    throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(db)))
                }
            }
        }
    }

    private func prepareLocked(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }
}

extension OpaquePointer {
    func columnText(_ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(self, index) else { return nil }
        return String(cString: cString)
    }

    func columnInt(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(self, index))
    }
}
