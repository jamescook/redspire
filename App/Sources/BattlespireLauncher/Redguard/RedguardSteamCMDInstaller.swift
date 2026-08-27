import Foundation

/// steamcmd support for Redguard's Steam release (AppID 1812410, depot
/// 1812411 -- confirmed via public anonymous steamcmd metadata, which also
/// showed a Redguard/SAVEGAME path, confirming the same installRoot/Redguard/
/// shape already built for the GOG and raw-disc installers). UNVERIFIED
/// against a real purchase -- no Steam copy of this game was bought for
/// this work. Thin wrapper over the same Shared/ helpers SteamCMDInstaller
/// uses.
enum RedguardSteamCMDInstaller {
    static let appID = "1812410"

    static var installDestination: URL {
        AppSupportDirectory.root
            .appendingPathComponent("RedguardSteam", isDirectory: true)
    }

    static func command(username: String, destDir: String) -> String {
        SteamCMDCommandBuilder.command(appID: appID, username: username, destDir: destDir)
    }

    static func findInstalledGameDir(root: URL = installDestination, fileManager: FileManager = .default) -> String? {
        SteamCMDGameFinder.findInstalledGameDir(
            exeRelativePath: "Redguard/REDGUARD.EXE", root: root, fileManager: fileManager
        )
    }
}
