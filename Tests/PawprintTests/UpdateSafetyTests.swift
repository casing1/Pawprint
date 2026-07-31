import CryptoKit
import XCTest
import PawprintCore
@testable import Pawprint

/// Section G: the two decisions that stand between a published file and it becoming the app the
/// user runs.
///
/// Getting the version comparison wrong strands everyone on an old build or offers them a
/// downgrade. Getting the signature check wrong is worse: it is the only thing that makes a
/// substituted download URL not a substituted application.
final class UpdateSafetyTests: XCTestCase {

    // MARK: - Version comparison

    /// The reason this is not a string comparison. "1.10.0" sorts *below* "1.9.0" as text, which
    /// would have stopped offering updates the moment the minor version reached ten.
    func testTenComesAfterNine() {
        XCTAssertEqual(ReleaseVersion.compare("1.10.0", "1.9.0"), .orderedDescending)
        XCTAssertEqual(ReleaseVersion.compare("0.9.0", "0.10.0"), .orderedAscending)
        XCTAssertEqual(ReleaseVersion.compare("0.6.11", "0.6.9"), .orderedDescending)
    }

    func testEqualVersionsCompareSame() {
        XCTAssertEqual(ReleaseVersion.compare("0.7.0", "0.7.0"), .orderedSame)
        XCTAssertEqual(ReleaseVersion.compare("1.0", "1.0.0"), .orderedSame, "a missing component is zero")
        XCTAssertEqual(ReleaseVersion.compare("2", "2.0.0"), .orderedSame)
    }

    func testEachComponentIsWeighedInOrder() {
        XCTAssertEqual(ReleaseVersion.compare("1.0.0", "0.99.99"), .orderedDescending)
        XCTAssertEqual(ReleaseVersion.compare("0.7.1", "0.7.0"), .orderedDescending)
        XCTAssertEqual(ReleaseVersion.compare("0.7.0", "0.8.0"), .orderedAscending)
    }

    /// Tags carry suffixes. Stripping non-digits per component keeps "1.2.0-beta" at 1.2.0 rather
    /// than collapsing that component to zero and calling it older than 1.2.0.
    func testSuffixesDoNotChangeTheOrdering() {
        XCTAssertEqual(ReleaseVersion.compare("1.2.0-beta", "1.2.0"), .orderedSame)
        XCTAssertEqual(ReleaseVersion.compare("v1.3.0", "1.2.0"), .orderedDescending)
    }

    /// Nonsense must not read as newer. Anything unparseable becomes zero, which loses.
    func testUnparseableVersionsAreNotNewer() {
        XCTAssertFalse(ReleaseVersion.isNewer(version: "", build: nil,
                                              thanVersion: "0.7.0", build: "1"))
        XCTAssertFalse(ReleaseVersion.isNewer(version: "latest", build: nil,
                                              thanVersion: "0.7.0", build: "1"))
        XCTAssertFalse(ReleaseVersion.isNewer(version: "../../etc/passwd", build: nil,
                                              thanVersion: "0.7.0", build: "1"))
    }

    // MARK: - Builds

    func testABuildOnlyBreaksATieOnTheVersion() {
        // Same version, higher build: an update.
        XCTAssertTrue(ReleaseVersion.isNewer(version: "0.7.0", build: "42",
                                             thanVersion: "0.7.0", build: "41"))
        // Same version, same or lower build: not an update.
        XCTAssertFalse(ReleaseVersion.isNewer(version: "0.7.0", build: "41",
                                              thanVersion: "0.7.0", build: "41"))
        XCTAssertFalse(ReleaseVersion.isNewer(version: "0.7.0", build: "40",
                                              thanVersion: "0.7.0", build: "41"))
        // A higher build must never rescue an older version — this is what would offer a
        // republished 0.6.0 to somebody already running 0.7.0.
        XCTAssertFalse(ReleaseVersion.isNewer(version: "0.6.0", build: "9999",
                                              thanVersion: "0.7.0", build: "1"))
    }

    func testAMissingBuildOnATieIsNotAnUpdate() {
        XCTAssertFalse(ReleaseVersion.isNewer(version: "0.7.0", build: nil,
                                              thanVersion: "0.7.0", build: "1"))
    }

    /// The ordinary case, and the one that matters: a real release supersedes the shipping one.
    func testANewerReleaseIsOffered() {
        XCTAssertTrue(ReleaseVersion.isNewer(version: "0.8.0", build: nil,
                                             thanVersion: "0.7.0", build: "1"))
        XCTAssertFalse(ReleaseVersion.isNewer(version: "0.6.9", build: nil,
                                              thanVersion: "0.7.0", build: "1"))
    }

    // MARK: - Signatures

    private let archive = Data("PK\u{03}\u{04} pretend this is Pawprint.zip".utf8)

    private func keyPair() -> (privateKey: Curve25519.Signing.PrivateKey, publicBase64: String) {
        let key = Curve25519.Signing.PrivateKey()
        return (key, key.publicKey.rawRepresentation.base64EncodedString())
    }

    func testAGenuineSignatureIsAccepted() throws {
        let (privateKey, publicBase64) = keyPair()
        let signature = try privateKey.signature(for: archive).base64EncodedString()

        XCTAssertTrue(ReleaseSignature.isValid(payload: archive,
                                               signatureBase64: signature,
                                               publicKeyBase64: publicBase64))
    }

    /// The whole point. One flipped byte in the download and the signature no longer matches.
    func testATamperedArchiveIsRejected() throws {
        let (privateKey, publicBase64) = keyPair()
        let signature = try privateKey.signature(for: archive).base64EncodedString()

        var tampered = archive
        tampered[tampered.count - 1] ^= 0x01

        XCTAssertFalse(ReleaseSignature.isValid(payload: tampered,
                                                signatureBase64: signature,
                                                publicKeyBase64: publicBase64))
    }

    /// A correctly-formed signature from somebody else's key. This is the substituted-download
    /// case: the attacker can sign, just not with the key the app pins.
    func testASignatureFromAnotherKeyIsRejected() throws {
        let (_, publicBase64) = keyPair()
        let impostor = Curve25519.Signing.PrivateKey()
        let signature = try impostor.signature(for: archive).base64EncodedString()

        XCTAssertFalse(ReleaseSignature.isValid(payload: archive,
                                                signatureBase64: signature,
                                                publicKeyBase64: publicBase64))
    }

    /// Malformed input is a rejection, not an error to be swallowed somewhere upstream. Every one
    /// of these would be a pass if the check ever treated "couldn't verify" as "fine".
    func testMalformedInputIsAlwaysARejection() throws {
        let (privateKey, publicBase64) = keyPair()
        let signature = try privateKey.signature(for: archive).base64EncodedString()

        let bad: [(String, String, String)] = [
            ("empty signature", "", publicBase64),
            ("not base64", "this is not base64 !!!", publicBase64),
            ("truncated signature", String(signature.dropLast(8)), publicBase64),
            ("empty key", signature, ""),
            ("key of the wrong length", signature, Data(repeating: 7, count: 16).base64EncodedString()),
            ("key that is not base64", signature, "!!!!"),
        ]
        for (name, signature, key) in bad {
            XCTAssertFalse(ReleaseSignature.isValid(payload: archive,
                                                    signatureBase64: signature,
                                                    publicKeyBase64: key),
                           "accepted an update with \(name)")
        }
    }

    /// The workflow uploads the signature as a `.sig` asset, and a file has a trailing newline.
    func testSurroundingWhitespaceIsTolerated() throws {
        let (privateKey, publicBase64) = keyPair()
        let signature = try privateKey.signature(for: archive).base64EncodedString()

        XCTAssertTrue(ReleaseSignature.isValid(payload: archive,
                                               signatureBase64: "\n  \(signature)  \n",
                                               publicKeyBase64: publicBase64))
    }

    /// An empty archive must not be a special case that passes without a matching signature.
    func testAnEmptyArchiveStillNeedsAMatchingSignature() throws {
        let (privateKey, publicBase64) = keyPair()
        let signatureOverArchive = try privateKey.signature(for: archive).base64EncodedString()

        XCTAssertFalse(ReleaseSignature.isValid(payload: Data(),
                                                signatureBase64: signatureOverArchive,
                                                publicKeyBase64: publicBase64))
        let signatureOverNothing = try privateKey.signature(for: Data()).base64EncodedString()
        XCTAssertTrue(ReleaseSignature.isValid(payload: Data(),
                                               signatureBase64: signatureOverNothing,
                                               publicKeyBase64: publicBase64))
    }

    // MARK: - The pinned key

    /// The shipping key must be a usable Ed25519 public key. A typo here would reject every
    /// release, and nothing else in the build would notice.
    func testThePinnedPublicKeyIsAValidEd25519Key() throws {
        let raw = try XCTUnwrap(Data(base64Encoded: UpdateDistribution.publicKey),
                                "the pinned key is not base64")
        XCTAssertEqual(raw.count, 32, "an Ed25519 public key is 32 bytes")
        XCTAssertNoThrow(try Curve25519.Signing.PublicKey(rawRepresentation: raw))
    }

    /// The feed the app ships with is the project's own, over TLS.
    func testTheDefaultFeedIsHTTPS() {
        XCTAssertTrue(UpdateDistribution.feedURL.hasPrefix("https://"))
    }
}
