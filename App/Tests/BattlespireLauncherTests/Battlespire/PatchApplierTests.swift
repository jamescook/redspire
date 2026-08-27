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

        write("v1.5", to: patchDir.appendingPathComponent("GAME.EXE"))
        write("v1.3", to: gameDir.appendingPathComponent("GAME.EXE"))

        try makeDir(patchDir.appendingPathComponent("GAMEDATA"))
        write("new", to: patchDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT"))
        try makeDir(gameDir.appendingPathComponent("GAMEDATA"))
        write("old", to: gameDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT"))

        try PatchApplier.apply(patchDir: patchDir.path, toGameDir: gameDir.path)

        #expect(contents(of: gameDir.appendingPathComponent("GAME.EXE")) == Data("v1.5".utf8))
        #expect(contents(of: gameDir.appendingPathComponent("GAMEDATA/LEVEL1.DAT")) == Data("new".utf8))
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

        write("v1.5", to: patchDir.appendingPathComponent("game.exe"))
        write("v1.3", to: gameDir.appendingPathComponent("GAME.EXE"))

        try makeDir(patchDir.appendingPathComponent("gamedata"))
        write("new", to: patchDir.appendingPathComponent("gamedata/xbow.3d"))
        try makeDir(gameDir.appendingPathComponent("GAMEDATA"))

        try PatchApplier.apply(patchDir: patchDir.path, toGameDir: gameDir.path)

        #expect(contents(of: gameDir.appendingPathComponent("GAME.EXE")) == Data("v1.5".utf8))
        #expect(contents(of: gameDir.appendingPathComponent("GAMEDATA/xbow.3d")) == Data("new".utf8))
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
        write("v1.5", to: patchDir.appendingPathComponent("GAME.EXE"))
        write("v1.3", to: gameDir.appendingPathComponent("GAME.EXE"))

        let runner = FakeProcessRunner() // never touched: it's a folder, not a zip
        try PatchApplier.applyFromZipOrFolder(path: patchDir.path, toGameDir: gameDir.path, runner: runner)

        #expect(contents(of: gameDir.appendingPathComponent("GAME.EXE")) == Data("v1.5".utf8))
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
        write("v1.5", to: nested.appendingPathComponent("GAME.EXE"))
        write("v1.3", to: gameDir.appendingPathComponent("GAME.EXE"))

        // Picking the top-level folder (not the nested batpat15/ folder
        // itself) is exactly the reported bug: it used to fail with
        // patchFilesNotFound even though GAME.EXE was right there, one
        // level down.
        try PatchApplier.applyFromZipOrFolder(path: topLevel.path, toGameDir: gameDir.path, runner: FakeProcessRunner())

        #expect(contents(of: gameDir.appendingPathComponent("GAME.EXE")) == Data("v1.5".utf8))
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

    private func write(_ string: String, to url: URL) {
        FileManager.default.createFile(atPath: url.path, contents: Data(string.utf8))
    }

    private func makeDir(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func contents(of url: URL) -> Data? {
        FileManager.default.contents(atPath: url.path)
    }
}
