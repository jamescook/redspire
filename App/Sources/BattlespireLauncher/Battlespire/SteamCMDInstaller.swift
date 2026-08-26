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
        AppSupportDirectory.root
            .appendingPathComponent("Steam", isDirectory: true)
    }

    static func command(username: String, destDir: String) -> String {
        SteamCMDCommandBuilder.command(appID: appID, username: username, destDir: destDir)
    }

    /// Looks for GAME.EXE at `root` (defaults to installDestination), or one
    /// level down -- Steam's depot layout for this title isn't independently
    /// confirmed, so this doesn't assume it's flat the way GOG's installer is.
    /// `root` is injectable so this can be tested against a real temp
    /// directory instead of ~/Library/Application Support. Thin wrapper over
    /// SteamCMDGameFinder (Shared/) -- see RedguardSteamCMDInstaller for the
    /// other real consumer of that shared logic.
    static func findInstalledGameDir(root: URL = installDestination, fileManager: FileManager = .default) -> String? {
        SteamCMDGameFinder.findInstalledGameDir(exeRelativePath: "GAME.EXE", root: root, fileManager: fileManager)
    }
}
