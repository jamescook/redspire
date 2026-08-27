import Foundation

/// Finds an existing Steam install of Redguard (AppID 1812410, confirmed
/// via public anonymous steamcmd metadata -- +app_info_print needs no
/// purchase, only downloading the depot does). Thin wrapper over
/// SteamGameDetector (Shared/), same as SteamDetector is for Battlespire.
enum RedguardSteamDetector {
    static let appID = "1812410"

    static func findGameDirectory(
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        fileProvider: FileProviding = RealFileProvider()
    ) -> String? {
        SteamGameDetector.findGameDirectory(
            appID: appID,
            exeRelativePath: "Redguard/REDGUARD.EXE",
            homeDirectory: homeDirectory,
            fileProvider: fileProvider
        )
    }
}
