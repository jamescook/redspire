import Testing
import Foundation
@testable import Redspire

struct RedguardDiscImageInstallerLogicTests {
    // MARK: - findDataCab

    @Test func findsDataCabCaseInsensitively() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("data1.cab").path, contents: Data())

        #expect(RedguardDiscImageInstaller.findDataCab(atMountRoot: dir.path) == "data1.cab")
    }

    @Test func returnsNilWhenNoDataCab() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(RedguardDiscImageInstaller.findDataCab(atMountRoot: dir.path) == nil)
    }

    // MARK: - needsSoundConfig

    @Test func needsSoundConfigWhenFileMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(RedguardDiscImageInstaller.needsSoundConfig(atPath: dir.appendingPathComponent("DIG.INI").path, fileManager: .default) == true)
    }

    @Test func needsSoundConfigWhenOnlyEmptyGSetSoundStub() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stub = ";\n;Miles Sound System V4.0d of 30-Mar-98\n;DIG.INI File output by GSetSound\n;written by Craig Walton.\n;Copyright 1998 Bethesda Softworks.\n;\n"
        let path = dir.appendingPathComponent("DIG.INI").path
        FileManager.default.createFile(atPath: path, contents: Data(stub.utf8))

        #expect(RedguardDiscImageInstaller.needsSoundConfig(atPath: path, fileManager: .default) == true)
    }

    @Test func doesNotNeedSoundConfigWhenRealDeviceLinePresent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let real = "DEVICE      Creative Labs SoundBlaster 16, AWE32 or AWE64\nDRIVER      SB16.DIG\n"
        let path = dir.appendingPathComponent("DIG.INI").path
        FileManager.default.createFile(atPath: path, contents: Data(real.utf8))

        #expect(RedguardDiscImageInstaller.needsSoundConfig(atPath: path, fileManager: .default) == false)
    }

    // MARK: - resolveStage

    @Test func nonZeroExitFails() {
        let stage = RedguardDiscImageInstaller.resolveStage(exitCode: 2, redguardExeExists: false, rgfxExeExists: false, hasGlideDriver: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("2"))
    }

    @Test func zeroExitButMissingRedguardExeFails() {
        let stage = RedguardDiscImageInstaller.resolveStage(exitCode: 0, redguardExeExists: false, rgfxExeExists: false, hasGlideDriver: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("REDGUARD.EXE"))
    }

    /// Regression test: RGFX.EXE (the game's Glide-accelerated renderer,
    /// what actually gets launched) lives at the disc root, not inside
    /// DATA1.CAB -- unshield never extracts it, so this has to be checked
    /// for separately from REDGUARD.EXE. Missing it silently produced an
    /// install that failed at launch with a cryptic DOS "Illegal command"
    /// instead of a clear error here.
    @Test func zeroExitButMissingRgfxExeFails() {
        let stage = RedguardDiscImageInstaller.resolveStage(exitCode: 0, redguardExeExists: true, rgfxExeExists: false, hasGlideDriver: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("RGFX.EXE"))
    }

    @Test func successWithoutGlideDriverNeedsGlideDriver() {
        let stage = RedguardDiscImageInstaller.resolveStage(exitCode: 0, redguardExeExists: true, rgfxExeExists: true, hasGlideDriver: false, gameDir: "/tmp/x")
        #expect(stage == .needsGlideDriver(gameDir: "/tmp/x"))
    }

    @Test func successWithGlideDriverSucceeds() {
        let stage = RedguardDiscImageInstaller.resolveStage(exitCode: 0, redguardExeExists: true, rgfxExeExists: true, hasGlideDriver: true, gameDir: "/tmp/x")
        #expect(stage == .done(gameDir: "/tmp/x"))
    }

    // MARK: - supplyGlideDriver

    @Test @MainActor func supplyGlideDriverCopiesFileAndCompletes() throws {
        // gameDir is the folder mounted as C: (containing Redguard/), not
        // Redguard/ itself -- matches RedguardGameSession's expectation.
        // Regression test for a real bug: this previously wrote the file
        // straight into gameDir, one level too shallow, so REDGUARD.EXE
        // lookups at launch failed with gameDir set from a completed disc
        // install.
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("glide2x_emu.ovl")
        FileManager.default.createFile(atPath: source.path, contents: Data("driver bytes".utf8))
        let gameDir = dir
        try FileManager.default.createDirectory(at: gameDir.appendingPathComponent("Redguard"), withIntermediateDirectories: true)

        let installer = RedguardDiscImageInstaller()
        installer.supplyGlideDriver(fromPath: source.path, gameDir: gameDir.path)

        #expect(installer.stage == .done(gameDir: gameDir.path))
        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("Redguard/GLIDE2X.OVL").path) == Data("driver bytes".utf8))
    }

    // MARK: - deallocation mid-extraction

    /// Regression test for a real leak: the onExit closure used to guard its
    /// whole body (including the DiscMounter.unmount call) on `self` still
    /// being alive when unshield's process exit fired. If the installer was
    /// deallocated first -- e.g. the wizard sheet dismissed mid-extraction,
    /// nothing else retaining it -- the mounted disc image was silently
    /// never detached and stayed mounted indefinitely.
    @Test @MainActor func unmountsDiscEvenWhenDeallocatedBeforeUnshieldExits() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("DATA1.CAB").path, contents: Data())

        let destRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: destRoot) }

        let runner = DeferredExitRunner(mountPoint: dir.path)
        var installer: RedguardDiscImageInstaller? = RedguardDiscImageInstaller(
            runner: runner, unshieldPath: { "/usr/bin/true" }, destinationRoot: destRoot
        )
        installer?.extract(isoPath: "/tmp/fake.iso")
        await drainMainActorTasks()

        installer = nil // deallocated before unshield's process exit fires
        runner.fireExit(0)
        await drainMainActorTasks()

        #expect(runner.syncCalls.contains { $0.arguments.contains("detach") })
    }

    /// Mounts successfully (runSync, for hdiutil) and, on runAsync, holds
    /// onto the onExit callback instead of firing it immediately -- lets a
    /// test deallocate the installer before simulating unshield's exit.
    private final class DeferredExitRunner: ProcessRunning {
        let mountPoint: String
        private(set) var syncCalls: [(executable: String, arguments: [String])] = []
        private var pendingExit: ((Int32) -> Void)?

        init(mountPoint: String) { self.mountPoint = mountPoint }

        func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
            syncCalls.append((executable, arguments))
            guard arguments.contains("attach") else { return (0, "") }
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>system-entities</key><array>
            <dict><key>mount-point</key><string>\(mountPoint)</string></dict>
            </array></dict></plist>
            """
            return (0, plist)
        }

        func runAsync(executable: String, arguments: [String], onOutput: @escaping (String) -> Void, onExit: @escaping (Int32) -> Void) -> ProcessHandle {
            pendingExit = onExit
            return FakeProcessHandle()
        }

        func fireExit(_ exitCode: Int32) {
            pendingExit?(exitCode)
        }
    }

    // MARK: - reset

    /// Real bug: the wizard never called reset() on this object, so
    /// re-selecting "I have the original disc(s)" after any earlier attempt
    /// (even a stale/interrupted one) jumped straight to that old stage
    /// instead of a fresh "Choose Disc 1 Image..." button.
    @Test @MainActor func resetIsNoOpWhileRunning() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("DATA1.CAB").path, contents: Data())

        // destinationRoot MUST be a separate throwaway temp dir here (not
        // `dir`, which simulates the mounted disc) -- extract()
        // unconditionally wipes and recreates it. Real bug found live: an
        // earlier version of this test, without this override, destroyed
        // the user's actual extracted disc install on every `swift test`
        // run.
        let destRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: destRoot) }

        let runner = HangingUnshieldRunner(mountPoint: dir.path)
        let installer = RedguardDiscImageInstaller(runner: runner, unshieldPath: { "/usr/bin/true" }, destinationRoot: destRoot)

        installer.extract(isoPath: "/tmp/fake.iso")
        await drainMainActorTasks()
        #expect(installer.isRunning == true)
        #expect(installer.stage == .extracting)
        #expect(installer.log == "extracting...\n")

        installer.reset()
        #expect(installer.stage == .extracting)
        #expect(installer.log == "extracting...\n")
    }

    /// Mounts successfully (runSync, for hdiutil) but never completes the
    /// unshield extraction (runAsync never calls onExit) -- simulates an
    /// in-flight attempt to verify reset() doesn't wipe its visible state.
    private final class HangingUnshieldRunner: ProcessRunning {
        let mountPoint: String
        init(mountPoint: String) { self.mountPoint = mountPoint }

        func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>system-entities</key><array>
            <dict><key>mount-point</key><string>\(mountPoint)</string></dict>
            </array></dict></plist>
            """
            return (0, plist)
        }

        func runAsync(executable: String, arguments: [String], onOutput: @escaping (String) -> Void, onExit: @escaping (Int32) -> Void) -> ProcessHandle {
            onOutput("extracting...\n")
            return FakeProcessHandle()
        }
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
