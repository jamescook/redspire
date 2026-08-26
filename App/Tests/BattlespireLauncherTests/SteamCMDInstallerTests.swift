import Testing
import Foundation
@testable import BattlespireLauncher

struct SteamCMDInstallerTests {
    @Test func commandUsesProvidedUsername() {
        let cmd = SteamCMDInstaller.command(username: "myuser", destDir: "/tmp/Steam")
        #expect(cmd == "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir \"/tmp/Steam\" +login myuser +app_update 1812420 validate +quit")
    }

    @Test func commandFallsBackToPlaceholderWhenUsernameEmpty() {
        let cmd = SteamCMDInstaller.command(username: "  ", destDir: "/tmp/Steam")
        #expect(cmd.contains("<your_steam_username>"))
    }

    // findInstalledGameDir's `root` param is injectable specifically so these
    // can point it at a real (throwaway) temp directory instead of the app's
    // actual ~/Library/Application Support location.

    @Test func findsGameExeAtRoot() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        FileManager.default.createFile(atPath: root.appendingPathComponent("GAME.EXE").path, contents: Data())

        #expect(SteamCMDInstaller.findInstalledGameDir(root: root) == root.path)
    }

    @Test func findsGameExeOneLevelDown() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("An Elder Scrolls Legend Battlespire")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: nested.appendingPathComponent("GAME.EXE").path, contents: Data())

        let found = try #require(SteamCMDInstaller.findInstalledGameDir(root: root))
        #expect(URL(fileURLWithPath: found).resolvingSymlinksInPath().path == nested.resolvingSymlinksInPath().path)
    }

    @Test func returnsNilWhenNothingInstalled() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(SteamCMDInstaller.findInstalledGameDir(root: root) == nil)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
