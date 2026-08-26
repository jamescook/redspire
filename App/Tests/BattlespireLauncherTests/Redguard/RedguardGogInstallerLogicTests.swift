import Testing
import Foundation
@testable import BattlespireLauncher

struct RedguardGogInstallerLogicTests {
    // MARK: - resolveStage

    @Test func nonZeroExitFails() {
        let stage = RedguardGogInstaller.resolveStage(exitCode: 2, redguardExeExists: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("2"))
    }

    @Test func zeroExitButMissingRedguardExeFails() {
        let stage = RedguardGogInstaller.resolveStage(exitCode: 0, redguardExeExists: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("REDGUARD.EXE"))
    }

    @Test func zeroExitWithRedguardExeSucceeds() {
        let stage = RedguardGogInstaller.resolveStage(exitCode: 0, redguardExeExists: true, gameDir: "/tmp/x")
        #expect(stage == .done(gameDir: "/tmp/x"))
    }

    // MARK: - needsGlideDriver

    @Test func needsGlideDriverWhenAbsent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(RedguardGogInstaller.needsGlideDriver(redguardDir: dir.path, fileManager: .default) == true)
    }

    @Test func doesNotNeedGlideDriverWhenAlreadyPresent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("GLIDE2X.OVL").path, contents: Data())
        #expect(RedguardGogInstaller.needsGlideDriver(redguardDir: dir.path, fileManager: .default) == false)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
