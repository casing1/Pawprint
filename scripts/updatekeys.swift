// Ed25519 keys for signing update archives.
//
// Auto-update can't lean on code signing here: GitHub Actions has no access to a personal
// signing certificate, so CI builds are ad-hoc signed, and an ad-hoc bundle's designated
// requirement is a content hash that by definition never matches the next build. Pinning our own
// public key in the app gives a trust anchor that survives rebuilds and doesn't need an Apple
// Developer account. Same model Sparkle uses.
//
//   swift scripts/updatekeys.swift generate
//   PAWPRINT_UPDATE_PRIVATE_KEY=<base64> swift scripts/updatekeys.swift sign <file>
//   swift scripts/updatekeys.swift verify <file> <signature-base64> <publickey-base64>

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { fail("usage: updatekeys.swift generate|sign|verify") }

switch arguments[1] {
case "generate":
    let key = Curve25519.Signing.PrivateKey()
    print("PRIVATE=\(key.rawRepresentation.base64EncodedString())")
    print("PUBLIC=\(key.publicKey.rawRepresentation.base64EncodedString())")

case "sign":
    guard arguments.count >= 3 else { fail("usage: sign <file>") }
    guard let encoded = ProcessInfo.processInfo.environment["PAWPRINT_UPDATE_PRIVATE_KEY"],
          let raw = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("PAWPRINT_UPDATE_PRIVATE_KEY missing or not a valid base64 Ed25519 private key")
    }
    guard let payload = FileManager.default.contents(atPath: arguments[2]) else {
        fail("cannot read \(arguments[2])")
    }
    guard let signature = try? key.signature(for: payload) else { fail("signing failed") }
    print(signature.base64EncodedString())

case "verify":
    guard arguments.count >= 5 else { fail("usage: verify <file> <signature> <publickey>") }
    guard let payload = FileManager.default.contents(atPath: arguments[2]) else {
        fail("cannot read \(arguments[2])")
    }
    guard let signature = Data(base64Encoded: arguments[3]),
          let rawKey = Data(base64Encoded: arguments[4]),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
        fail("bad signature or public key encoding")
    }
    if key.isValidSignature(signature, for: payload) {
        print("OK")
    } else {
        fail("SIGNATURE MISMATCH")
    }

default:
    fail("unknown command \(arguments[1])")
}
