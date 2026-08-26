import Foundation

/// Detection for `steamcmd`, Valve's official headless CLI -- lets a user
/// pull the game files without installing the full Steam GUI client.
enum SteamCMDTool {
    static let candidates = [
        "/opt/homebrew/bin/steamcmd",
        "/usr/local/bin/steamcmd",
    ]

    static var executablePath: String? {
        ExecutableLocator.firstExecutable(in: candidates)
    }

    static var isInstalled: Bool { executablePath != nil }
}

/// steamcmd needs an interactive password (and possibly a Steam Guard code),
/// which isn't something this app should collect and pipe through itself --
/// that's exactly the kind of credential handling best left to Steam's own
/// official CLI in a real terminal. So instead of driving steamcmd directly,
/// this hands the user a ready-to-run command for their own Terminal.
enum SteamCMDInstaller {
    static let appID = "1812420"

    static var installDestination: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BattlespireLauncher", isDirectory: true)
            .appendingPathComponent("Steam", isDirectory: true)
    }

    /// Pure: the exact command to copy into Terminal.
    ///
    /// Forces the Windows platform type: Battlespire's Steam depot only ships
    /// a Windows build (it's the same DOSBox-wrapped package GOG sells) --
    /// steamcmd otherwise defaults to downloading a macOS-native depot for
    /// the host OS, which doesn't exist for this title and fails with
    /// "Invalid platform".
    static func command(username: String, destDir: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        let user = trimmed.isEmpty ? "<your_steam_username>" : trimmed
        return "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir \"\(destDir)\" +login \(user) +app_update \(appID) validate +quit"
    }

    /// Looks for GAME.EXE at `root` (defaults to installDestination), or one
    /// level down -- Steam's depot layout for this title isn't independently
    /// confirmed, so this doesn't assume it's flat the way GOG's installer is.
    /// `root` is injectable so this can be tested against a real temp
    /// directory instead of ~/Library/Application Support.
    static func findInstalledGameDir(root: URL = installDestination, fileManager: FileManager = .default) -> String? {
        if fileManager.fileExists(atPath: root.appendingPathComponent("GAME.EXE").path) {
            return root.path
        }
        guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            if fileManager.fileExists(atPath: child.appendingPathComponent("GAME.EXE").path) {
                return child.path
            }
        }
        return nil
    }
}
