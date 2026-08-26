import Foundation

/// Builds the ready-to-paste-into-Terminal steamcmd command for the
/// "run it myself" install path. Shared between Battlespire's and Redguard's
/// installers -- only the AppID differs.
enum SteamCMDCommandBuilder {
    /// Pure: the exact command to copy into Terminal.
    ///
    /// Forces the Windows platform type: neither game's Steam depot ships a
    /// macOS-native build (both are the same DOSBox-wrapped package GOG
    /// sells) -- steamcmd otherwise defaults to downloading a macOS depot
    /// for the host OS, which doesn't exist for either title and fails with
    /// "Invalid platform".
    static func command(appID: String, username: String, destDir: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        let user = trimmed.isEmpty ? "<your_steam_username>" : trimmed
        return "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir \"\(destDir)\" +login \(user) +app_update \(appID) validate +quit"
    }
}
