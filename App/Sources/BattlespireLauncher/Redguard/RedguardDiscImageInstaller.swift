import Foundation

enum RedguardDiscInstallStage: Equatable {
    case extracting
    case needsGlideDriver(gameDir: String)
    case done(gameDir: String)
    case failed(String)
}

/// Handles Redguard's raw retail disc: unlike Battlespire's disc (a plain
/// DOS file tree you can just copy), Disc 1 is a real Windows InstallShield
/// package (SETUP.EXE / DATA1.CAB) -- needs `unshield` to unpack without
/// running Windows. Confirmed via a real extraction that unshield -d puts
/// Common_Files/3DFX_Art/Xngine_Art directly under the destination.
///
/// Two landmines match Battlespire's disc-install pattern, confirmed by
/// direct inspection: sound/DIG.INI and MDI.INI exist but are empty
/// GSetSound stub files (header comment only, no DEVICE line) rather than
/// literally missing, and GLIDE2X.OVL (the DOS Glide driver RGFX.EXE needs)
/// isn't on the disc at all. Unlike Battlespire's SPIRE.CFG/DIG.INI, this
/// app can't bundle a GLIDE2X.OVL template itself -- it's a third-party
/// 3dfx-authored binary of unclear redistribution rights, not something
/// DOSBox/SVN-Daum wrote. Extraction still succeeds without it; the stage
/// becomes .needsGlideDriver so the wizard can ask the user to supply their
/// own legitimate copy (e.g. from a GOG install of the same game). See
/// REDGUARD.md.
@MainActor
final class RedguardDiscImageInstaller: ObservableObject {
    @Published private(set) var stage: RedguardDiscInstallStage?
    @Published private(set) var log = ""
    @Published private(set) var isRunning = false

    private let runner: ProcessRunning
    private let unshieldPath: () -> String?
    private let destinationRoot: URL
    private nonisolated(unsafe) var handle: ProcessHandle?

    /// `destinationRoot` is injectable specifically so tests can point this
    /// at a throwaway temp directory instead of the app's real
    /// ~/Library/Application Support location -- a real bug found live:
    /// tests that faked the process runner but not this destroyed the
    /// user's actual extracted disc install on every `swift test` run,
    /// since extract() unconditionally wipes and recreates it.
    init(
        runner: ProcessRunning = SystemProcessRunner(),
        unshieldPath: @escaping () -> String? = { UnshieldTool.executablePath },
        destinationRoot: URL = AppSupportDirectory.root.appendingPathComponent("RedguardDisc", isDirectory: true)
    ) {
        self.runner = runner
        self.unshieldPath = unshieldPath
        self.destinationRoot = destinationRoot
    }

    /// Pure: the on-disk name of the InstallShield cabinet, if present.
    nonisolated static func findDataCab(atMountRoot root: String, fileManager: FileManager = .default) -> String? {
        CaseInsensitiveFileLookup.resolveActualName(in: root, matching: "DATA1.CAB", fileManager: fileManager)
    }

    /// Pure: does the sound config at `path` still need replacing -- true
    /// both when it's missing entirely and when it's the disc's own empty
    /// GSetSound stub (header comment only, no real DEVICE line).
    nonisolated static func needsSoundConfig(atPath path: String, fileManager: FileManager) -> Bool {
        guard let data = fileManager.contents(atPath: path), let text = String(data: data, encoding: .ascii) else {
            return true
        }
        return !text.contains("DEVICE")
    }

    /// Pure mapping from the unshield outcome to the resulting stage.
    nonisolated static func resolveStage(
        exitCode: Int32, redguardExeExists: Bool, rgfxExeExists: Bool, hasGlideDriver: Bool, gameDir: String
    ) -> RedguardDiscInstallStage {
        guard exitCode == 0 else {
            return .failed("unshield exited with status \(exitCode). See log above.")
        }
        guard redguardExeExists else {
            return .failed("Extraction finished, but REDGUARD.EXE wasn't found at the expected location.")
        }
        guard rgfxExeExists else {
            return .failed("Extraction finished, but RGFX.EXE (the game's renderer) wasn't found on the disc image.")
        }
        guard hasGlideDriver else {
            return .needsGlideDriver(gameDir: gameDir)
        }
        return .done(gameDir: gameDir)
    }

    func extract(isoPath: String) {
        guard let unshieldExe = unshieldPath() else {
            stage = .failed("unshield isn't installed.")
            return
        }

        let mountPoint: String
        do {
            mountPoint = try DiscMounter.mount(isoPath, runner: runner)
        } catch {
            stage = .failed(error.localizedDescription)
            return
        }

        guard let cabName = Self.findDataCab(atMountRoot: mountPoint) else {
            DiscMounter.unmount(mountPoint, runner: runner)
            stage = .failed(
                "Couldn't find DATA1.CAB inside that disc image -- this doesn't look like the Redguard install disc."
            )
            return
        }
        let cabPath = (mountPoint as NSString).appendingPathComponent(cabName)

        let dest = destinationRoot
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            DiscMounter.unmount(mountPoint, runner: runner)
            stage = .failed("Couldn't prepare install folder: \(error.localizedDescription)")
            return
        }

        log = ""
        stage = .extracting
        isRunning = true

        // Captured by value (not through self) so the disc image still gets
        // unmounted even if this installer is deallocated mid-extraction --
        // e.g. the wizard sheet is dismissed before unshield finishes and
        // nothing else retains this instance. Leaving unmount behind a
        // `guard let self` left the mounted volume orphaned in that case.
        nonisolated(unsafe) let runner = self.runner
        handle = runner.runAsync(
            executable: unshieldExe,
            arguments: ["x", "-d", dest.path, cabPath],
            onOutput: { [weak self] chunk in
                Task { @MainActor in self?.log += chunk }
            },
            onExit: { [weak self] exitCode in
                Task { @MainActor in
                    // finish() reads RGFX.EXE from mountPoint (it lives at
                    // the disc root, not inside DATA1.CAB -- unshield never
                    // sees it), so it must run before unmounting. It's
                    // skipped if self is already gone, but the unmount below
                    // must still happen regardless.
                    self?.finish(exitCode: exitCode, dest: dest, mountPoint: mountPoint)
                    DiscMounter.unmount(mountPoint, runner: runner)
                }
            }
        )
    }

    /// The user points us at their own legitimately-sourced GLIDE2X.OVL
    /// (e.g. from a GOG install of the same game) once .needsGlideDriver.
    /// `gameDir` here means the same thing it does everywhere else in this
    /// class and in RedguardGameSession: the folder mounted as C: (which
    /// contains a Redguard/ subfolder), not the Redguard/ folder itself.
    func supplyGlideDriver(fromPath sourcePath: String, gameDir: String) {
        let dst = (gameDir as NSString).appendingPathComponent("Redguard/GLIDE2X.OVL")
        do {
            try? FileManager.default.removeItem(atPath: dst)
            try FileManager.default.copyItem(atPath: sourcePath, toPath: dst)
            stage = .done(gameDir: gameDir)
        } catch {
            stage = .failed("Couldn't copy that file: \(error.localizedDescription)")
        }
    }

    private func finish(exitCode: Int32, dest: URL, mountPoint: String) {
        isRunning = false
        handle = nil

        let commonFiles = dest.appendingPathComponent("Common_Files")
        let fxart = dest.appendingPathComponent("3DFX_Art/fxart")
        let redguardDir = dest.appendingPathComponent("Redguard")

        if exitCode == 0, FileManager.default.fileExists(atPath: commonFiles.path) {
            try? mergeExtractedFiles(commonFiles: commonFiles, fxart: fxart, mountPoint: mountPoint, into: redguardDir)
        }

        let exeExists = FileManager.default.fileExists(atPath: redguardDir.appendingPathComponent("REDGUARD.EXE").path)
        let rgfxExists = FileManager.default.fileExists(atPath: redguardDir.appendingPathComponent("RGFX.EXE").path)
        let hasGlide = !RedguardGogInstaller.needsGlideDriver(redguardDir: redguardDir.path, fileManager: .default)

        // gameDir is dest, not redguardDir: RedguardGameSession mounts this
        // as C: and does `cd redguard` itself, matching RedguardGogInstaller's
        // same convention (its own gameDir is the folder containing Redguard/,
        // not Redguard/ itself).
        stage = Self.resolveStage(
            exitCode: exitCode,
            redguardExeExists: exeExists,
            rgfxExeExists: rgfxExists,
            hasGlideDriver: hasGlide,
            gameDir: dest.path
        )
    }

    private func mergeExtractedFiles(commonFiles: URL, fxart: URL, mountPoint: String, into redguardDir: URL) throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: redguardDir)
        try fileManager.createDirectory(at: redguardDir, withIntermediateDirectories: true)
        for item in try fileManager.contentsOfDirectory(atPath: commonFiles.path) {
            try? fileManager.copyItem(
                atPath: commonFiles.appendingPathComponent(item).path,
                toPath: redguardDir.appendingPathComponent(item).path
            )
        }
        if fileManager.fileExists(atPath: fxart.path) {
            try? fileManager.copyItem(at: fxart, to: redguardDir.appendingPathComponent("fxart"))
        }
        // RGFX.EXE (the Glide-accelerated renderer this app actually
        // launches) lives at the disc root, not inside DATA1.CAB -- unshield
        // never sees it. Confirmed byte-identical to GOG's own copy of it.
        if let rgfxName = CaseInsensitiveFileLookup.resolveActualName(
            in: mountPoint, matching: "RGFX.EXE", fileManager: fileManager
        ) {
            try? fileManager.copyItem(
                atPath: (mountPoint as NSString).appendingPathComponent(rgfxName),
                toPath: redguardDir.appendingPathComponent("RGFX.EXE").path
            )
        }
        try fillInSoundConfig(redguardDir: redguardDir)
    }

    private func fillInSoundConfig(redguardDir: URL) throws {
        let soundDir = redguardDir.appendingPathComponent("sound")
        for (bundledName, destName) in [("REDGUARD_DIG.INI", "DIG.INI"), ("REDGUARD_MDI.INI", "MDI.INI")] {
            let dst = soundDir.appendingPathComponent(destName)
            guard Self.needsSoundConfig(atPath: dst.path, fileManager: .default) else { continue }
            guard let templateURL = BundledResource.url(named: bundledName) else { continue }
            try? FileManager.default.removeItem(at: dst)
            try FileManager.default.copyItem(at: templateURL, to: dst)
        }
    }

    func cancel() {
        handle?.terminate()
    }

    /// No-op while actually running -- never silently hides an in-progress
    /// attempt's visible state just because the wizard navigated away and
    /// back to this screen. Real bug: the wizard didn't call this anywhere,
    /// so re-selecting "I have the original disc(s)" after any earlier
    /// attempt (even a stale/interrupted one) showed that old stage
    /// instead of a fresh "Choose Disc 1 Image..." button.
    func reset() {
        guard !isRunning else { return }
        stage = nil
        log = ""
    }

    deinit {
        handle?.terminate()
    }
}
