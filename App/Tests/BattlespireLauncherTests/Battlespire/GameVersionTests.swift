import Testing
import Foundation
@testable import BattlespireLauncher

struct GameVersionTests {
    @Test func detectsV15FromSyntheticBytes() {
        let data = Data("junk\0\0\0Battlespire V1.5\0more junk".utf8)
        #expect(GameVersion.detect(inBytes: data) == "Battlespire V1.5")
    }

    @Test func detectsV13FromSyntheticBytes() {
        let data = Data("\u{01}\u{02}Battlespire V1.3 retail\u{00}".utf8)
        #expect(GameVersion.detect(inBytes: data) == "Battlespire V1.3 retail")
    }

    @Test func caseInsensitive() {
        let data = Data("BATTLESPIRE v1.5".utf8)
        #expect(GameVersion.detect(inBytes: data) == "BATTLESPIRE v1.5")
    }

    @Test func returnsNilWhenAbsent() {
        let data = Data("nothing relevant here".utf8)
        #expect(GameVersion.detect(inBytes: data) == nil)
    }

    @Test func shortRunsBelowStringsMinLengthAreIgnored() {
        // "v1.5" alone without "battlespire" preceding it shouldn't match --
        // the phrase "battlespire v" must appear together.
        let data = Data("some other v1.5 mention, no game name nearby".utf8)
        #expect(GameVersion.detect(inBytes: data) == nil)
    }

    @Test func isV15() {
        #expect(GameVersion.isV15("Battlespire V1.5"))
        #expect(GameVersion.isV15("Battlespire v1.5b"))
        #expect(!GameVersion.isV15("Battlespire V1.3"))
        #expect(!GameVersion.isV15(nil))
    }
}
