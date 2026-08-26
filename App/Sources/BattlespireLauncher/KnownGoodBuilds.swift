import Foundation
import CryptoKit

/// SHA-256 hashes of GAME.EXE from verified-legitimate v1.5 builds. Informational
/// only (a "this exact build was checked" badge) -- the version-string check in
/// GameVersion is what actually gates compatibility, since GOG/Steam could
/// legitimately rebuild v1.5 with different bytes later.
enum KnownGoodBuilds {
    static let gameExeSHA256: Set<String> = [
        "a07299044a65d3294450ada6312908c90d26a6b265d13806010dd16527e0ee3e",
    ]

    static func sha256Hex(ofFileAt path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return sha256Hex(of: data)
    }

    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Pure -- given a hash, is it in the known-good set. Testable without any file.
    static func isVerified(hash: String) -> Bool {
        gameExeSHA256.contains(hash)
    }

    static func isVerified(gameExePath: String) -> Bool {
        guard let hash = sha256Hex(ofFileAt: gameExePath) else { return false }
        return isVerified(hash: hash)
    }
}
