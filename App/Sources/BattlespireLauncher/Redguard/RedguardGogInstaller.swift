import Foundation

enum RedguardGogInstallStage: Equatable {
    case extracting
    case done(gameDir: String)
    case failed(String)
}

/// Runs `innoextract` against a GOG offline installer for Redguard, off the
/// main thread, mirroring GogInstaller's shape. Genuinely differs from it in
/// one confirmed way: GOG's Redguard installer nests everything under an
/// `app/` subfolder even with `--gog --output-dir` (verified via a real
/// extraction) -- Battlespire's own installer doesn't do this. `gameDir` in
/// `.done` is that `app/` folder (what gets mounted as C: -- it contains
/// both `Redguard/`, where RGFX.EXE and its config actually live, and
/// `game.ins`).
@MainActor
final class RedguardGogInstaller: ObservableObject {
    @Published private(set) var stage: RedguardGogInstallStage?
    @Published private(set) var log = ""
    @Published private(set) var isRunning = false

    private let runner: ProcessRunning
    private let innoExtractPath: () -> String?
    private let destinationRoot: URL
    private nonisolated(unsafe) var handle: ProcessHandle?

    /// `destinationRoot` is injectable specifically so tests can point this
    /// at a throwaway temp directory instead of the app's real
    /// ~/Library/Application Support location -- see GogInstaller's
    /// identical parameter for the real bug this fixes.
    init(
        runner: ProcessRunning = SystemProcessRunner(),
        innoExtractPath: @escaping () -> String? = { InnoExtractTool.executablePath },
        destinationRoot: URL = AppSupportDirectory.root
    ) {
        self.runner = runner
        self.innoExtractPath = innoExtractPath
        self.destinationRoot = destinationRoot
    }

    /// Pure mapping from the extraction outcome to the resulting UI stage.
    nonisolated static func resolveStage(exitCode: Int32, redguardExeExists: Bool, gameDir: String) -> RedguardGogInstallStage {
        guard exitCode == 0 else {
            return .failed("innoextract exited with status \(exitCode). See log above.")
        }
        guard redguardExeExists else {
            return .failed("Extraction finished, but REDGUARD.EXE wasn't found at the expected location. This installer's layout may differ from the version this app was tested against.")
        }
        return .done(gameDir: gameDir)
    }

    /// Pure: does `redguardDir` already have its own GLIDE2X.OVL. RGFX.EXE
    /// needs this (the DOS Glide driver DOSBox's Voodoo emulation looks
    /// for), but neither the Redguard folder nor the raw retail disc ships
    /// one -- GOG's own installer does though, as a sibling used by their
    /// bundled DOSBox fork. Copying it from there means we're moving a file
    /// the user's own legitimate purchase already extracted, not bundling
    /// or redistributing a copy ourselves.
    nonisolated static func needsGlideDriver(redguardDir: String, fileManager: FileManager) -> Bool {
        !fileManager.fileExists(atPath: (redguardDir as NSString).appendingPathComponent("GLIDE2X.OVL"))
    }

    func extract(installerPath: String) {
        guard let exe = innoExtractPath() else {
            stage = .failed("innoextract isn't installed.")
            return
        }

        let sizeMB = (try? FileManager.default.attributesOfItem(atPath: installerPath)[.size] as? Int64).flatMap { $0 }
            .map { Double($0) / 1_048_576 } ?? 0
        let probe = runner.runSync(executable: exe, arguments: ["-l", installerPath])
        if let reason = GogInstaller.rejectionMessage(installerIsValidInno: probe.exitCode == 0, sizeMB: sizeMB) {
            stage = .failed(reason)
            return
        }

        let dest = destinationRoot.appendingPathComponent("RedguardGOG", isDirectory: true)

        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            stage = .failed("Couldn't prepare install folder: \(error.localizedDescription)")
            return
        }

        log = ""
        stage = .extracting
        isRunning = true

        handle = runner.runAsync(
            executable: exe,
            arguments: ["--gog", "--output-dir", dest.path, installerPath],
            onOutput: { [weak self] s in
                Task { @MainActor in self?.log += s }
            },
            onExit: { [weak self] exitCode in
                Task { @MainActor in self?.finish(exitCode: exitCode, dest: dest) }
            }
        )
    }

    private func finish(exitCode: Int32, dest: URL) {
        isRunning = false
        handle = nil

        let appRoot = dest.appendingPathComponent("app")
        let redguardDir = appRoot.appendingPathComponent("Redguard")
        let redguardExe = redguardDir.appendingPathComponent("REDGUARD.EXE").path
        let exists = FileManager.default.fileExists(atPath: redguardExe)

        if exists, Self.needsGlideDriver(redguardDir: redguardDir.path, fileManager: .default) {
            let src = appRoot.appendingPathComponent("DOSBOX/glide2x_emu.ovl")
            try? FileManager.default.copyItem(at: src, to: redguardDir.appendingPathComponent("GLIDE2X.OVL"))
        }

        stage = Self.resolveStage(exitCode: exitCode, redguardExeExists: exists, gameDir: appRoot.path)
    }

    func cancel() {
        handle?.terminate()
    }

    /// No-op while actually running -- never silently hides an in-progress
    /// attempt's visible state just because the wizard navigated away and
    /// back to this screen.
    func reset() {
        guard !isRunning else { return }
        stage = nil
        log = ""
    }

    deinit {
        // See GogInstaller's deinit -- without this, closing mid-extract
        // leaves innoextract running as an orphan.
        handle?.terminate()
    }
}
