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

/// Creates a double-clickable Desktop shortcut for one game mode. The
/// shortcut is a tiny AppleScript stub app (built with the system's own
/// osacompile, no bundled dependency) whose only job is to reopen this same
/// Redspire app via its `redspire://launch/<mode>` URL -- it contains no
/// game-launching logic of its own, so double-clicking it always goes
/// through RootView's normal direct-launch dispatch and the same
/// GameSession/RedguardGameSession play() a Play-button click would use,
/// never bypassing this app's own install validation.
enum DesktopShortcutCreator {
    static let defaultDesktopURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop")

    /// Where a given mode's shortcut lives (or would be created), shared by
    /// createShortcut/isInstalled here and by AppDefaultsReset's cleanup so
    /// all three agree on the exact same path.
    nonisolated static func shortcutURL(for mode: GameMode, desktopURL: URL = defaultDesktopURL) -> URL {
        desktopURL.appendingPathComponent("\(mode.displayName).app")
    }

    @discardableResult
    static func createShortcut(
        for mode: GameMode,
        desktopURL: URL = defaultDesktopURL,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let appURL = shortcutURL(for: mode, desktopURL: desktopURL)
        // Overwrites a stale shortcut from an earlier run of this same
        // action -- osacompile itself refuses to write over an existing
        // path.
        try? fileManager.removeItem(at: appURL)

        let script = "open location \"\(DirectLaunchURL.url(for: mode).absoluteString)\""
        let result = runner.runSync(executable: "/usr/bin/osacompile", arguments: ["-o", appURL.path, "-e", script])
        guard result.exitCode == 0 else {
            throw DesktopShortcutError.osacompileFailed("osacompile exited with status \(result.exitCode)")
        }

        // Best-effort: a shortcut with the generic AppleScript icon still
        // works, so a failure loading the game's own icon here isn't fatal.
        if let iconURL = BundledResource.url(named: mode.iconFileName, fileManager: fileManager),
           let icon = NSImage(contentsOf: iconURL) {
            NSWorkspace.shared.setIcon(icon, forFile: appURL.path)
        }

        return appURL
    }

    /// True only if a shortcut for `mode` exists on the Desktop AND its
    /// compiled script actually points at this mode's own direct-launch URL
    /// -- not just that some file happens to have the expected name (e.g. a
    /// stale shortcut left over from before a rename, or an unrelated file).
    /// osadecompile round-trips osacompile's output back to readable source,
    /// so this is a real content check, not just an existence check.
    static func isInstalled(
        for mode: GameMode,
        desktopURL: URL = defaultDesktopURL,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default
    ) -> Bool {
        let appURL = shortcutURL(for: mode, desktopURL: desktopURL)
        guard fileManager.fileExists(atPath: appURL.path) else { return false }
        let result = runner.runSync(executable: "/usr/bin/osadecompile", arguments: [appURL.path])
        guard result.exitCode == 0 else { return false }
        return result.output.contains(DirectLaunchURL.url(for: mode).absoluteString)
    }
}
