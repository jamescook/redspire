import Foundation

/// Finds an existing Steam install of Battlespire (AppID 1812420). Thin
/// wrapper over SteamGameDetector (Shared/) -- see RedguardSteamDetector for
/// the other real consumer of that shared logic.
enum SteamDetector {
    static let appID = "1812420"

    static func findGameDirectory(
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        fileProvider: FileProviding = RealFileProvider()
    ) -> String? {
        SteamGameDetector.findGameDirectory(
            appID: appID, exeRelativePath: "GAME.EXE", homeDirectory: homeDirectory, fileProvider: fileProvider
        )
    }

    static func libraryPaths(fromVDFText text: String) -> [String] {
        SteamGameDetector.libraryPaths(fromVDFText: text)
    }

    static func installDir(fromManifestText text: String) -> String? {
        SteamGameDetector.installDir(fromManifestText: text)
    }
}
