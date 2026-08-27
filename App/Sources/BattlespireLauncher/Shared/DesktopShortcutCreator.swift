import SwiftUI

enum DesktopShortcutError: LocalizedError {
    case osacompileFailed(String)

    var errorDescription: String? {
        switch self {
        case .osacompileFailed(let reason):
            return "Couldn't create the shortcut: \(reason)"
        }
    }
}

/// Creates a Desktop shortcut for one game mode. Prefers a small Finder
/// alias pointing at a pre-built stub app bundled inside this app's own
/// Resources/Shortcuts/ (built and signed by build.sh alongside the main
/// app, with the same real Developer ID identity) -- a genuine shortcut,
/// not a second full app copied onto the Desktop, and properly signed so it
/// doesn't hit Gatekeeper's "unidentified developer" block the way an
/// ad-hoc-signed osacompile output does. Falls back to compiling a stub on
/// the fly (the original approach) when no pre-built one is bundled -- true
/// under `swift run`/`swift test`, which never go through build.sh. Either
/// way, the shortcut's only job is reopening this same app via its
/// `redspire://launch/<mode>` URL -- it contains no game-launching logic of
/// its own, so double-clicking it always goes through RootView's normal
/// direct-launch dispatch and the same GameSession/RedguardGameSession
/// play() a Play-button click would use, never bypassing this app's own
/// install validation.
enum DesktopShortcutCreator {
    static let defaultDesktopURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop")

    /// Where a given mode's shortcut lives (or would be created), shared by
    /// createShortcut/isInstalled here and by AppDefaultsReset's cleanup so
    /// all three agree on the exact same path.
    nonisolated static func shortcutURL(for mode: GameMode, desktopURL: URL = defaultDesktopURL) -> URL {
        desktopURL.appendingPathComponent("\(mode.displayName).app")
    }

    /// Where build.sh places each mode's pre-built, signed stub app, if
    /// this is a real build.sh-produced app bundle rather than a
    /// `swift run`/`swift test` dev build.
    static func defaultPrebuiltStubURL(for mode: GameMode, fileManager: FileManager = .default) -> URL? {
        BundledResource.url(named: "Shortcuts/\(mode.displayName).app", fileManager: fileManager)
    }

    @discardableResult
    static func createShortcut(
        for mode: GameMode,
        desktopURL: URL = defaultDesktopURL,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default,
        prebuiltStubLookup: (GameMode) -> URL? = { defaultPrebuiltStubURL(for: $0) }
    ) throws -> URL {
        let appURL = shortcutURL(for: mode, desktopURL: desktopURL)
        // Overwrites a stale shortcut from an earlier run of this same
        // action -- osacompile itself refuses to write over an existing
        // path, and writeBookmarkData isn't guaranteed to either.
        try? fileManager.removeItem(at: appURL)

        if let prebuiltStub = prebuiltStubLookup(mode), fileManager.fileExists(atPath: prebuiltStub.path) {
            let bookmark = try prebuiltStub.bookmarkData(options: [.suitableForBookmarkFile])
            try URL.writeBookmarkData(bookmark, to: appURL)
        } else {
            let script = "open location \"\(DirectLaunchURL.url(for: mode).absoluteString)\""
            let result = runner.runSync(executable: "/usr/bin/osacompile", arguments: ["-o", appURL.path, "-e", script])
            guard result.exitCode == 0 else {
                throw DesktopShortcutError.osacompileFailed("osacompile exited with status \(result.exitCode)")
            }
        }

        // Best-effort: a shortcut with the generic icon still works, so a
        // failure loading the game's own icon here isn't fatal. Aliases can
        // carry their own custom icon independent of their target, same as
        // a regular file.
        if let iconURL = BundledResource.url(named: mode.iconFileName, fileManager: fileManager),
           let icon = NSImage(contentsOf: iconURL) {
            NSWorkspace.shared.setIcon(icon, forFile: appURL.path)
        }

        return appURL
    }

    /// True only if a shortcut for `mode` exists on the Desktop AND
    /// actually resolves to (or, for the on-the-fly-compiled fallback,
    /// decompiles to) this mode's own direct-launch URL -- not just that
    /// some file happens to have the expected name (e.g. a stale shortcut
    /// left over from before a rename, or an unrelated file).
    static func isInstalled(
        for mode: GameMode,
        desktopURL: URL = defaultDesktopURL,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default,
        prebuiltStubLookup: (GameMode) -> URL? = { defaultPrebuiltStubURL(for: $0) }
    ) -> Bool {
        let appURL = shortcutURL(for: mode, desktopURL: desktopURL)
        guard fileManager.fileExists(atPath: appURL.path) else { return false }

        if let expectedTarget = prebuiltStubLookup(mode),
           let bookmark = try? URL.bookmarkData(withContentsOf: appURL) {
            var isStale = false
            let resolved = try? URL(
                resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale
            )
            return resolved?.standardizedFileURL == expectedTarget.standardizedFileURL
        }

        // Dev/test fallback: a directly-compiled stub app rather than an
        // alias -- osadecompile round-trips osacompile's output back to
        // readable source, so this is still a real content check.
        let result = runner.runSync(executable: "/usr/bin/osadecompile", arguments: [appURL.path])
        guard result.exitCode == 0 else { return false }
        return result.output.contains(DirectLaunchURL.url(for: mode).absoluteString)
    }
}
