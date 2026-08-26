import Testing
import Foundation
@testable import BattlespireLauncher

struct DiscImageInstallerTests {
    @Test func findsGameDirAtRoot() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("GAME.EXE").path, contents: Data())

        #expect(DiscImageInstaller.findGameDir(atRoot: dir.path) == dir.path)
    }

    @Test func findsGameDirWithLowercaseFilename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.exe").path, contents: Data())

        #expect(DiscImageInstaller.findGameDir(atRoot: dir.path) == dir.path)
    }

    @Test func resolveActualNameIsCaseInsensitive() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("game.exe").path, contents: Data())

        #expect(DiscImageInstaller.resolveActualName(in: dir.path, matching: "GAME.EXE") == "game.exe")
        #expect(DiscImageInstaller.resolveActualName(in: dir.path, matching: "MISSING.EXE") == nil)
    }

    @Test func findsGameDirOneLevelDown() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let nested = dir.appendingPathComponent("batspire")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: nested.appendingPathComponent("GAME.EXE").path, contents: Data())

        let found = try #require(DiscImageInstaller.findGameDir(atRoot: dir.path))
        #expect(URL(fileURLWithPath: found).resolvingSymlinksInPath().path == nested.resolvingSymlinksInPath().path)
    }

    @Test func returnsNilWhenNoGameExeAnywhere() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(DiscImageInstaller.findGameDir(atRoot: dir.path) == nil)
    }

    @Test func parsesMountPointFromHdiutilPlist() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>system-entities</key>
            <array>
                <dict>
                    <key>content-hint</key>
                    <string>Apple_partition_scheme</string>
                    <key>dev-entry</key>
                    <string>/dev/disk4</string>
                </dict>
                <dict>
                    <key>content-hint</key>
                    <string>Apple_ISO</string>
                    <key>dev-entry</key>
                    <string>/dev/disk4s1</string>
                    <key>mount-point</key>
                    <string>/Volumes/BATTLESPIRE</string>
                </dict>
            </array>
        </dict>
        </plist>
        """
        #expect(DiscImageInstaller.parseMountPoint(fromHdiutilPlistOutput: plist) == "/Volumes/BATTLESPIRE")
    }

    @Test func returnsNilForGarbagePlistOutput() {
        #expect(DiscImageInstaller.parseMountPoint(fromHdiutilPlistOutput: "not a plist") == nil)
    }

    @Test func fillsInMSSFromSiblingWhenMissing() throws {
        // Reproduces the actual reported bug: a raw retail disc has MSS as
        // a sibling of the batspire/ folder, not inside it.
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let gameDir = root.appendingPathComponent("batspire")
        try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data())

        let mss = root.appendingPathComponent("mss")
        try FileManager.default.createDirectory(at: mss, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: mss.appendingPathComponent("SBPRO.DIG").path, contents: Data("driver".utf8))

        try DiscImageInstaller.fillInMissingSupportFiles(gameDir: gameDir.path, mountRoot: root.path)

        #expect(DiscImageInstaller.resolveActualName(in: gameDir.path, matching: "MSS") != nil)
        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("MSS/SBPRO.DIG").path) == Data("driver".utf8))
        // The actual reported bug: the disc's own mss/ folder lacks DIG.INI
        // too (confirmed by direct A/B testing this alone caused the severe
        // animation slowdown) -- copying MSS in isn't sufficient by itself.
        #expect(DiscImageInstaller.resolveActualName(in: gameDir.appendingPathComponent("MSS").path, matching: "DIG.INI") != nil)
    }

    @Test func synthesizesDigIniWhenMSSExistsButDigIniIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let gameDir = root.appendingPathComponent("batspire")
        let mss = gameDir.appendingPathComponent("MSS")
        try FileManager.default.createDirectory(at: mss, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data())
        FileManager.default.createFile(atPath: mss.appendingPathComponent("SBPRO.DIG").path, contents: Data())

        try DiscImageInstaller.fillInMissingSupportFiles(gameDir: gameDir.path, mountRoot: root.path)

        let digName = try #require(DiscImageInstaller.resolveActualName(in: mss.path, matching: "DIG.INI"))
        let content = try #require(FileManager.default.contents(atPath: mss.appendingPathComponent(digName).path))
        #expect(String(data: content, encoding: .ascii)?.contains("Miles Sound System") == true)
    }

    @Test func synthesizesSpireCFGWhenAbsentEverywhere() throws {
        // The real bug: a raw retail disc has no SPIRE.CFG at all --
        // the original installer generates it, and this app never runs that.
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let gameDir = root.appendingPathComponent("batspire")
        try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data())

        try DiscImageInstaller.fillInMissingSupportFiles(gameDir: gameDir.path, mountRoot: root.path)

        let cfgName = try #require(DiscImageInstaller.resolveActualName(in: gameDir.path, matching: "SPIRE.CFG"))
        let cfgContent = try #require(FileManager.default.contents(atPath: gameDir.appendingPathComponent(cfgName).path))
        #expect(String(data: cfgContent, encoding: .ascii)?.contains("path         C:\\") == true)
    }

    @Test func leavesExistingSpireCFGAndMSSAlone() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let gameDir = root.appendingPathComponent("batspire")
        try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("GAME.EXE").path, contents: Data())
        FileManager.default.createFile(atPath: gameDir.appendingPathComponent("SPIRE.CFG").path, contents: Data("custom".utf8))
        try FileManager.default.createDirectory(at: gameDir.appendingPathComponent("MSS"), withIntermediateDirectories: true)

        try DiscImageInstaller.fillInMissingSupportFiles(gameDir: gameDir.path, mountRoot: root.path)

        #expect(FileManager.default.contents(atPath: gameDir.appendingPathComponent("SPIRE.CFG").path) == Data("custom".utf8))
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
