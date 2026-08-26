import Testing
@testable import Redspire

/// Focused on what actually differs from Battlespire's SteamDetector --
/// AppID and the exe-relative-path check. The VDF-parsing logic itself is
/// shared (SteamGameDetector) and already covered by SteamDetectorTests.
struct RedguardSteamDetectorTests {
    private let sampleManifest = """
    "AppState"
    {
    	"appid"		"1812410"
    	"universe"		"1"
    	"name"		"The Elder Scrolls Adventures: Redguard"
    	"StateFlags"		"4"
    	"installdir"		"The Elder Scrolls Adventures Redguard"
    }
    """

    @Test func findsGameDirectoryWhenRedguardExeIsNestedUnderRedguardSubfolder() {
        let home = "/Users/tester"
        let manifestPath = "\(home)/Library/Application Support/Steam/steamapps/appmanifest_1812410.acf"
        let exePath = "\(home)/Library/Application Support/Steam/steamapps/common/The Elder Scrolls Adventures Redguard/Redguard/REDGUARD.EXE"
        let provider = FakeFileProvider(files: [manifestPath: sampleManifest], existingPaths: [exePath])

        let found = RedguardSteamDetector.findGameDirectory(homeDirectory: home, fileProvider: provider)
        #expect(found == "\(home)/Library/Application Support/Steam/steamapps/common/The Elder Scrolls Adventures Redguard")
    }

    @Test func returnsNilWhenRedguardExeMissingEvenIfManifestExists() {
        let home = "/Users/tester"
        let manifestPath = "\(home)/Library/Application Support/Steam/steamapps/appmanifest_1812410.acf"
        let provider = FakeFileProvider(files: [manifestPath: sampleManifest], existingPaths: [])

        #expect(RedguardSteamDetector.findGameDirectory(homeDirectory: home, fileProvider: provider) == nil)
    }
}
