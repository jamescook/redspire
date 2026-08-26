import Testing
import Foundation
@testable import Redspire

struct CDImageDetectorTests {
    @Test func findsInsRegardlessOfFilename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("Battlespire.ins").path, contents: Data())
        FileManager.default.createFile(atPath: dir.appendingPathComponent("Battlespire.bin").path, contents: Data())

        let found = CDImageDetector.autoDetect(inGameDir: dir.path)
        #expect(found == dir.appendingPathComponent("Battlespire.ins").path)
    }

    @Test func prefersInsOverCueOverIso() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.iso").path, contents: Data())
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.cue").path, contents: Data())
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.ins").path, contents: Data())

        let found = CDImageDetector.autoDetect(inGameDir: dir.path)
        #expect(found == dir.appendingPathComponent("game.ins").path)
    }

    @Test func fallsBackToCueWhenNoIns() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.cue").path, contents: Data())

        let found = CDImageDetector.autoDetect(inGameDir: dir.path)
        #expect(found == dir.appendingPathComponent("game.cue").path)
    }

    @Test func returnsNilWhenNothingMatches() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("GAME.EXE").path, contents: Data())

        #expect(CDImageDetector.autoDetect(inGameDir: dir.path) == nil)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
