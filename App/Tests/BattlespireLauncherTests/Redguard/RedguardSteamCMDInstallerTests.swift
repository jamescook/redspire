import Testing
import Foundation
@testable import BattlespireLauncher

struct RedguardSteamCMDInstallerTests {
    @Test func commandUsesRedguardAppID() {
        let cmd = RedguardSteamCMDInstaller.command(username: "myuser", destDir: "/tmp/RedguardSteam")
        #expect(cmd == "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir \"/tmp/RedguardSteam\" +login myuser +app_update 1812410 validate +quit")
    }

    @Test func commandFallsBackToPlaceholderWhenUsernameEmpty() {
        let cmd = RedguardSteamCMDInstaller.command(username: "  ", destDir: "/tmp/RedguardSteam")
        #expect(cmd.contains("<your_steam_username>"))
    }

    @Test func findsGameDirWhenRedguardExeAtRoot() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let redguardDir = root.appendingPathComponent("Redguard")
        try FileManager.default.createDirectory(at: redguardDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: redguardDir.appendingPathComponent("REDGUARD.EXE").path, contents: Data())

        #expect(RedguardSteamCMDInstaller.findInstalledGameDir(root: root) == root.path)
    }

    @Test func findsGameDirOneLevelDown() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let installDir = root.appendingPathComponent("The Elder Scrolls Adventures Redguard")
        let redguardDir = installDir.appendingPathComponent("Redguard")
        try FileManager.default.createDirectory(at: redguardDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: redguardDir.appendingPathComponent("REDGUARD.EXE").path, contents: Data())

        let found = try #require(RedguardSteamCMDInstaller.findInstalledGameDir(root: root))
        #expect(URL(fileURLWithPath: found).resolvingSymlinksInPath().path == installDir.resolvingSymlinksInPath().path)
    }

    @Test func returnsNilWhenNothingInstalled() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(RedguardSteamCMDInstaller.findInstalledGameDir(root: root) == nil)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
