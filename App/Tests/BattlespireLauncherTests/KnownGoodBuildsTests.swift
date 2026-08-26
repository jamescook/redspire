import Testing
import Foundation
@testable import BattlespireLauncher

struct KnownGoodBuildsTests {
    @Test func recognizesKnownHash() {
        let hash = "a07299044a65d3294450ada6312908c90d26a6b265d13806010dd16527e0ee3e"
        #expect(KnownGoodBuilds.isVerified(hash: hash))
    }

    @Test func rejectsUnknownHash() {
        #expect(!KnownGoodBuilds.isVerified(hash: "0000000000000000000000000000000000000000000000000000000000000000"))
    }

    @Test func sha256HexMatchesExpectedDigest() {
        // Known SHA-256 of the empty string.
        let hash = KnownGoodBuilds.sha256Hex(of: Data())
        #expect(hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
}
