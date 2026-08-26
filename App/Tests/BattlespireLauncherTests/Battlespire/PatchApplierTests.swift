import Testing
import Foundation
@testable import Redspire

struct PatchApplierTests {
    @Test func copiesExeAndOverwritesGameData() throws {
        let patchDir = try makeTempDir()
        let gameDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: patchDir)
            try? FileManager.default.removeItem(at: gameDir)
        }

        FileManager.default.createFile(atPath: patchDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.5".utf8))
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.3".utf8))

        try FileManager.default.createDirectory(at: patchDir.appendingPathComponent("GAMEDATA"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: patchDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT").path, contents: Data("new".utf8))
        try FileManager.default.createDirectory(at: gameDir.appendingPathComponent("GAMEDATA"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT").path, contents: Data("old".utf8))

        try PatchApplier.apply(patchDir: patchDir.path, toGameDir: gameDir.path)

        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAME.EXE").path) == Data("v1.5".utf8))
        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT").path) == Data("new".utf8))
    }

    @Test func matchesLowercaseFilenamesLikeTheRealOfficialPatch() throws {
        // The real batpat15.zip ships "game.exe" and "gamedata/" lowercase
        // (confirmed via `unzip -l`), not "GAME.EXE"/"GAMEDATA" -- this is
        // the actual reported bug, not a hypothetical.
        let patchDir = try makeTempDir()
        let gameDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: patchDir)
            try? FileManager.default.removeItem(at: gameDir)
        }

        FileManager.default.createFile(atPath: patchDir.appendingPathComponent("game.exe").path, contents: Data("v1.5".utf8))
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.3".utf8))

        try FileManager.default.createDirectory(at: patchDir.appendingPathComponent("gamedata"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: patchDir.appendingPathComponent("gamedata/xbow.3d").path, contents: Data("new".utf8))
        try FileManager.default.createDirectory(at: gameDir.appendingPathComponent("GAMEDATA"), withIntermediateDirectories: true)

        try PatchApplier.apply(patchDir: patchDir.path, toGameDir: gameDir.path)

        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAME.EXE").path) == Data("v1.5".utf8))
        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAMEDATA/xbow.3d").path) == Data("new".utf8))
    }

    @Test func throwsWhenPatchExeMissing() throws {
        let patchDir = try makeTempDir()
        let gameDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: patchDir)
            try? FileManager.default.removeItem(at: gameDir)
        }

        #expect(throws: PatchApplier.ApplyError.self) {
            try PatchApplier.apply(patchDir: patchDir.path, toGameDir: gameDir.path)
        }
    }

    @Test func passesThroughDirectlyForAnAlreadyExtractedFolder() throws {
        let patchDir = try makeTempDir()
        let gameDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: patchDir)
            try? FileManager.default.removeItem(at: gameDir)
        }
        FileManager.default.createFile(atPath: patchDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.5".utf8))
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.3".utf8))

        let runner = FakeProcessRunner() // never touched: it's a folder, not a zip
        try PatchApplier.applyFromZipOrFolder(path: patchDir.path, toGameDir: gameDir.path, runner: runner)

        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAME.EXE").path) == Data("v1.5".utf8))
        #expect(runner.syncCalls.isEmpty)
    }

    @Test func findsGameExeOneLevelDownInAPickedFolder() throws {
        let topLevel = try makeTempDir()
        let gameDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: topLevel)
            try? FileManager.default.removeItem(at: gameDir)
        }
        let nested = topLevel.appendingPathComponent("batpat15")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: nested.appendingPathComponent("GAME.EXE").path, contents: Data("v1.5".utf8))
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data("v1.3".utf8))

        // Picking the top-level folder (not the nested batpat15/ folder
        // itself) is exactly the reported bug: it used to fail with
        // patchFilesNotFound even though GAME.EXE was right there, one
        // level down.
        try PatchApplier.applyFromZipOrFolder(path: topLevel.path, toGameDir: gameDir.path, runner: FakeProcessRunner())

        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("GAME.EXE").path) == Data("v1.5".utf8))
    }

    @Test func surfacesUnzipFailure() throws {
        let gameDir = try makeTempDir()
        let fakeZip = try makeTempDir().appendingPathComponent("batpat15.zip")
        FileManager.default.createFile(atPath: fakeZip.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: gameDir) }

        let runner = FakeProcessRunner()
        runner.syncResult = (exitCode: 1, output: "corrupt archive")

        #expect(throws: PatchApplier.ApplyError.self) {
            try PatchApplier.applyFromZipOrFolder(path: fakeZip.path, toGameDir: gameDir.path, runner: runner)
        }
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
