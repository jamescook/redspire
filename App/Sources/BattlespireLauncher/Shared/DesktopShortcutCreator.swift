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
    @discardableResult
    static func createShortcut(
        for mode: GameMode,
        desktopURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let appURL = desktopURL.appendingPathComponent("\(mode.displayName).app")
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
}
