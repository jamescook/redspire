import Foundation

/// Applies the official v1.5 patch to an existing install. This app never
/// fetches the patch itself (same reasoning as never fetching the game
/// installers) -- the user downloads it from a source they trust, and this
/// just does the file copy, which is all "applying" it actually means:
/// there's no installer, just GAME.EXE and GAMEDATA/* to overwrite.
enum PatchApplier {
    enum ApplyError: LocalizedError {
        case patchFilesNotFound
        case zipExtractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .patchFilesNotFound:
                return "Couldn't find GAME.EXE in that folder — make sure you selected the extracted patch files."
            case .zipExtractionFailed(let reason):
                return "Couldn't unzip that file: \(reason)"
            }
        }
    }

    /// Accepts either an already-extracted folder, or the raw batpat15.zip
    /// (the self-extracting batpat15.exe works too -- per the README, it's
    /// just a ZIP with a stub, and `unzip` finds the archive either way,
    /// without ever running the .exe). Either way, GAME.EXE might not be
    /// directly at the root -- both a zip extraction and a folder the user
    /// unpacked themselves can have it one level down (e.g. a batpat15/ or
    /// batspire/ subfolder) -- so both paths go through the same
    /// one-level-deep search before applying.
    static func applyFromZipOrFolder(
        path: String,
        toGameDir gameDir: String,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default
    ) throws {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        let searchRoot: String
        var scratchDirToClean: URL?

        if isDirectory.boolValue {
            searchRoot = path
        } else {
            let scratchDir = fileManager.temporaryDirectory
                .appendingPathComponent("BattlespirePatch-\(UUID().uuidString)")
            scratchDirToClean = scratchDir
            try fileManager.createDirectory(at: scratchDir, withIntermediateDirectories: true)

            let result = runner.runSync(executable: "/usr/bin/unzip", arguments: ["-o", path, "-d", scratchDir.path])
            guard result.exitCode == 0 else {
                throw ApplyError.zipExtractionFailed("unzip exited with status \(result.exitCode)")
            }
            searchRoot = scratchDir.path
        }

        defer { if let scratchDirToClean { try? fileManager.removeItem(at: scratchDirToClean) } }

        guard let patchDir = DiscImageInstaller.findGameDir(atRoot: searchRoot, fileManager: fileManager) else {
            throw ApplyError.patchFilesNotFound
        }
        try apply(patchDir: patchDir, toGameDir: gameDir, fileManager: fileManager)
    }

    /// Case-insensitive throughout: the official patch ships "game.exe" and
    /// "gamedata" lowercase, and relying on macOS's filesystem to paper over
    /// that silently was the actual bug here -- resolve real on-disk names
    /// explicitly instead of assuming they match our casing.
    static func apply(patchDir: String, toGameDir gameDir: String, fileManager: FileManager = .default) throws {
        guard let exeName = DiscImageInstaller.resolveActualName(
            in: patchDir, matching: "GAME.EXE", fileManager: fileManager
        ) else {
            throw ApplyError.patchFilesNotFound
        }
        let patchExe = (patchDir as NSString).appendingPathComponent(exeName)
        let destExe = (gameDir as NSString).appendingPathComponent("GAME.EXE")
        try safeCopyReplacing(from: patchExe, to: destExe, fileManager: fileManager)

        guard let dataName = DiscImageInstaller.resolveActualName(
            in: patchDir, matching: "GAMEDATA", fileManager: fileManager
        ) else {
            return
        }
        let patchData = (patchDir as NSString).appendingPathComponent(dataName)
        let destData = (gameDir as NSString).appendingPathComponent("GAMEDATA")
        for item in (try? fileManager.contentsOfDirectory(atPath: patchData)) ?? [] {
            let src = (patchData as NSString).appendingPathComponent(item)
            let dst = (destData as NSString).appendingPathComponent(item)
            try safeCopyReplacing(from: src, to: dst, fileManager: fileManager)
        }
    }

    /// Copies `source` to a temp file beside `destination` first, so a
    /// failure partway through the copy (disk full, source vanishes mid-copy
    /// on a flaky external volume, permissions) leaves `destination`
    /// untouched -- this is the one place in the app that overwrites a game
    /// install the user already has working, unlike every installer path
    /// which only wipes its destination after the fresh copy is validated.
    /// Only once the copy has fully succeeded do we remove the old file and
    /// move the temp file into place.
    private static func safeCopyReplacing(
        from source: String, to destination: String, fileManager: FileManager
    ) throws {
        let destDir = (destination as NSString).deletingLastPathComponent
        let tempDestination = (destDir as NSString).appendingPathComponent(".patch-\(UUID().uuidString).tmp")
        try fileManager.copyItem(atPath: source, toPath: tempDestination)
        do {
            if fileManager.fileExists(atPath: destination) {
                try fileManager.removeItem(atPath: destination)
            }
            try fileManager.moveItem(atPath: tempDestination, toPath: destination)
        } catch {
            try? fileManager.removeItem(atPath: tempDestination)
            throw error
        }
    }
}
