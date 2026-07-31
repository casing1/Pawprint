import CryptoKit
import Foundation

/// Deciding whether a published release is newer than the running one, and whether its archive is
/// the one that was signed.
///
/// Both answers used to live as private methods on `UpdateChecker`, which owns a URLSession, a
/// download task and an `@Observable` state machine. Neither could be exercised without one, and
/// both are pure functions of their inputs: one compares two strings, the other checks a signature.
/// They are the two places where getting it wrong means either never offering an update or
/// installing something that was not published.
package enum ReleaseVersion {

    /// Compares marketing versions component-wise.
    ///
    /// String comparison ranks "1.10.0" below "1.9.0", which would strand everyone on 1.9 forever.
    /// Non-digits are stripped per component so "1.2.0-beta" compares as "1.2.0" rather than
    /// collapsing to zero.
    package static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = components(lhs)
        let b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    /// Whether `version` (with an optional build) supersedes what is running.
    ///
    /// A build number only breaks a tie on the marketing version, never overrides it — otherwise a
    /// republished 0.6.0 with a higher build would offer itself to someone already on 0.7.0.
    package static func isNewer(version: String, build: String?,
                               thanVersion currentVersion: String, build currentBuild: String) -> Bool {
        switch compare(version, currentVersion) {
        case .orderedDescending: return true
        case .orderedAscending: return false
        case .orderedSame:
            guard let build else { return false }
            return compare(build, currentBuild) == .orderedDescending
        }
    }
}

/// The Ed25519 check that stands between a downloaded archive and it being unpacked.
package enum ReleaseSignature {

    /// True when `signature` is a valid Ed25519 signature over `payload` under `publicKey`.
    ///
    /// Both are base64. Anything malformed — a truncated signature, a key of the wrong length,
    /// text that is not base64 at all — is a *failure*, never a pass: this returns false rather
    /// than throwing, so there is no error path a caller can accidentally treat as success.
    ///
    /// The key is a parameter rather than the pinned constant so this can be tested at all. A test
    /// that could only ever use the shipping public key could prove a good signature is rejected,
    /// but never that a real one is accepted — nobody has the private half but the release
    /// workflow. `UpdateChecker` passes `UpdateDistribution.publicKey`.
    package static func isValid(payload: Data,
                                signatureBase64: String,
                                publicKeyBase64: String) -> Bool {
        let trimmed = signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let signature = Data(base64Encoded: trimmed),
              let rawKey = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
            return false
        }
        return key.isValidSignature(signature, for: payload)
    }
}
