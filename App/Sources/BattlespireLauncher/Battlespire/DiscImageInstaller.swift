import Foundation

/// Handles the "I have a raw disc image, not installed anywhere" case: the
/// original retail disc's data track contains both the small program that
/// belongs on the hard drive (GAME.EXE etc.) and, for this all-in-one .iso
/// case, that's the only copy of it that exists -- so it has to be pulled
/// out and copied to a normal folder before it can be MOUNTed as C:. The
/// .iso itself is kept as-is and used directly as the D: (CD) reference;
/// only the small program part gets copied out.
enum DiscImageInstaller {
    enum ExtractError: LocalizedError {
        case gameFilesNotFound

        var errorDescription: String? {
            switch self {
            case .gameFilesNotFound:
                return "Couldn't find the game's files inside that disc image."
            }
        }
    }

    static var installDestination: URL {
        AppSupportDirectory.root
            .appendingPathComponent("Disc", isDirectory: true)
    }

    /// Mounts `isoPath` read-only, copies the game folder out (searching one
    /// level of nesting, matching the retail disc's common BSPIRE/batspire/
    /// layout), then unmounts. Returns the copied folder's path.
    ///
    /// A raw retail disc is missing several things a working install needs,
    /// because they're normally produced by the original DOS/Windows
    /// installer, which this app never runs: SPIRE.CFG doesn't exist on the
    /// disc at all, and MSS/DIG.INI (the Sound Blaster 16 config for the
    /// Miles Sound System) is absent even from the disc's own mss/ folder.
    /// Confirmed by direct A/B testing that DIG.INI's absence alone is what
    /// caused the severe animation slowdown (the sound driver failing to
    /// init correctly and retrying/erroring in a way that manifested as
    /// heavy interrupt/page-table churn) -- not GAME.EXE version, not the CD
    /// image, not file location. GOG/Steam's packages already have
    /// everything baked in, which is why only the raw-disc path needs any
    /// of this. MSS itself also sits as a sibling of the batspire/ folder
    /// rather than inside it on the disc, so that gets copied in too.
    static func extractGameFiles(
        fromISO isoPath: String, runner: ProcessRunning = SystemProcessRunner()
    ) throws -> String {
        let mountPoint = try DiscMounter.mount(isoPath, runner: runner)
        defer { DiscMounter.unmount(mountPoint, runner: runner) }

        guard let sourceDir = Self.findGameDir(atRoot: mountPoint) else {
            throw ExtractError.gameFilesNotFound
        }

        let dest = installDestination
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try copyContents(of: sourceDir, to: dest.path)
        try fillInMissingSupportFiles(gameDir: dest.path, mountRoot: mountPoint)
        return dest.path
    }

    /// Copies MSS in from a sibling of the found game folder if it's missing
    /// (and present there), then writes the bundled SPIRE.CFG and
    /// MSS/DIG.INI templates for whichever of those are still missing.
    static func fillInMissingSupportFiles(
        gameDir: String, mountRoot: String, fileManager: FileManager = .default
    ) throws {
        if resolveActualName(in: gameDir, matching: "MSS", fileManager: fileManager) == nil,
           let mssName = resolveActualName(in: mountRoot, matching: "MSS", fileManager: fileManager) {
            let src = (mountRoot as NSString).appendingPathComponent(mssName)
            let dst = (gameDir as NSString).appendingPathComponent("MSS")
            try? fileManager.removeItem(atPath: dst)
            try fileManager.copyItem(atPath: src, toPath: dst)
        }

        try writeBundledTemplateIfMissing(named: "SPIRE.CFG", into: gameDir, fileManager: fileManager)

        let mssDir = (gameDir as NSString).appendingPathComponent(
            resolveActualName(in: gameDir, matching: "MSS", fileManager: fileManager) ?? "MSS"
        )
        if fileManager.fileExists(atPath: mssDir) {
            try writeBundledTemplateIfMissing(named: "DIG.INI", into: mssDir, fileManager: fileManager)
        }
    }

    private static func writeBundledTemplateIfMissing(
        named name: String, into dir: String, fileManager: FileManager
    ) throws {
        guard resolveActualName(in: dir, matching: name, fileManager: fileManager) == nil else { return }
        guard let templateURL = BundledResource.url(named: name, fileManager: fileManager) else {
            throw ExtractError.gameFilesNotFound
        }
        let dst = (dir as NSString).appendingPathComponent(name)
        try? fileManager.removeItem(atPath: dst)
        try fileManager.copyItem(at: templateURL, to: URL(fileURLWithPath: dst))
    }

    /// Searches `root` (and one level down) for a folder containing
    /// GAME.EXE. Case-insensitive: DOS is case-insensitive, and archives
    /// packaged on that side (the official patch ships "game.exe" lowercase)
    /// don't necessarily match our casing -- macOS's filesystem sometimes
    /// papers over that and sometimes doesn't, so this checks explicitly
    /// rather than relying on it. Pure given a FileManager, so it's testable
    /// against a real temp directory rather than an actually-mounted disc.
    static func findGameDir(atRoot root: String, fileManager: FileManager = .default) -> String? {
        if resolveActualName(in: root, matching: "GAME.EXE", fileManager: fileManager) != nil {
            return root
        }
        guard let children = try? fileManager.contentsOfDirectory(atPath: root) else { return nil }
        for child in children.sorted() {
            let childPath = (root as NSString).appendingPathComponent(child)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue else { continue }
            if resolveActualName(in: childPath, matching: "GAME.EXE", fileManager: fileManager) != nil {
                return childPath
            }
        }
        return nil
    }

    /// Pure: the on-disk name matching `name` case-insensitively, if any.
    static func resolveActualName(
        in dir: String, matching name: String, fileManager: FileManager = .default
    ) -> String? {
        CaseInsensitiveFileLookup.resolveActualName(in: dir, matching: name, fileManager: fileManager)
    }

    private static func copyContents(of sourceDir: String, to destDir: String) throws {
        let fileManager = FileManager.default
        for item in try fileManager.contentsOfDirectory(atPath: sourceDir) {
            let src = (sourceDir as NSString).appendingPathComponent(item)
            let dst = (destDir as NSString).appendingPathComponent(item)
            try? fileManager.removeItem(atPath: dst)
            try fileManager.copyItem(atPath: src, toPath: dst)
        }
    }
}
