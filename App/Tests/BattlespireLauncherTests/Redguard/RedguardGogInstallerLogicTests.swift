import Testing
import Foundation
@testable import Redspire

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

    // MARK: - reset

    /// Real bug: the wizard never called reset() on this object at all, so
    /// re-selecting "GOG" after any earlier attempt (even a failed one)
    /// showed that stale stage/log instead of starting fresh.
    @Test @MainActor func resetClearsStageAndLogWhenNotRunning() async throws {
        // destinationRoot MUST be a throwaway temp dir here -- see
        // GogInstallerLogicTests' identical comment for the real bug this
        // avoids (an earlier version of this test destroyed the user's
        // actual extracted install on every `swift test` run).
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "")
        runner.asyncExitCode = 2
        runner.asyncOutputLines = ["some output\n"]
        let installer = RedguardGogInstaller(runner: runner, innoExtractPath: { "/usr/bin/true" }, destinationRoot: tempRoot)

        installer.extract(installerPath: "/tmp/fake.exe")
        await drainMainActorTasks()
        #expect(installer.stage != nil)
        #expect(installer.log != "")

        installer.reset()
        #expect(installer.stage == nil)
        #expect(installer.log == "")
    }

    /// A hanging runner that never calls onExit, to prove reset() doesn't
    /// wipe an extraction's visible progress while it's still in flight.
    private final class HangingProcessRunner: ProcessRunning {
        func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
            (0, "")
        }

        func runAsync(executable: String, arguments: [String], onOutput: @escaping (String) -> Void, onExit: @escaping (Int32) -> Void) -> ProcessHandle {
            onOutput("extracting...\n")
            return FakeProcessHandle()
        }
    }

    @Test @MainActor func resetIsNoOpWhileRunning() async throws {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let installer = RedguardGogInstaller(runner: HangingProcessRunner(), innoExtractPath: { "/usr/bin/true" }, destinationRoot: tempRoot)

        installer.extract(installerPath: "/tmp/fake.exe")
        await drainMainActorTasks()
        #expect(installer.isRunning == true)
        #expect(installer.stage == .extracting)

        installer.reset()
        #expect(installer.stage == .extracting)
        #expect(installer.log == "extracting...\n")
    }
}
