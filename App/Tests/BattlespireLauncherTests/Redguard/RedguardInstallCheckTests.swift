import Testing
import Foundation
@testable import Redspire

struct RedguardInstallCheckTests {
    @Test func emptyGameDirIsNotComplete() {
        #expect(!RedguardInstallCheck.looksComplete(gameDir: ""))
    }

    @Test func missingBothExesIsNotComplete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(!RedguardInstallCheck.looksComplete(gameDir: dir.path))
    }

    @Test func missingOneExeIsNotComplete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let redguardDir = dir.appendingPathComponent("Redguard")
        try FileManager.default.createDirectory(at: redguardDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: redguardDir.appendingPathComponent("REDGUARD.EXE").path, contents: Data())

        #expect(!RedguardInstallCheck.looksComplete(gameDir: dir.path))
    }

    @Test func bothExesPresentIsComplete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let redguardDir = dir.appendingPathComponent("Redguard")
        try FileManager.default.createDirectory(at: redguardDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: redguardDir.appendingPathComponent("REDGUARD.EXE").path, contents: Data())
        FileManager.default.createFile(atPath: redguardDir.appendingPathComponent("RGFX.EXE").path, contents: Data())

        #expect(RedguardInstallCheck.looksComplete(gameDir: dir.path))
    }
}
