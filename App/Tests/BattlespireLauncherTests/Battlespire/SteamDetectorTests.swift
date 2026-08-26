import Testing
@testable import Redspire

struct SteamDetectorTests {
    private let sampleVDF = """
    "libraryfolders"
    {
    	"0"
    	{
    		"path"		"/Users/tester/Library/Application Support/Steam"
    		"label"		""
    		"apps"
    		{
    			"1812420"		"12345678"
    		}
    	}
    	"1"
    	{
    		"path"		"/Volumes/Games/SteamLibrary"
    		"apps"
    		{
    		}
    	}
    }
    """

    private let sampleManifest = """
    "AppState"
    {
    	"appid"		"1812420"
    	"universe"		"1"
    	"name"		"An Elder Scrolls Legend: Battlespire"
    	"StateFlags"		"4"
    	"installdir"		"An Elder Scrolls Legend Battlespire"
    }
    """

    @Test func parsesLibraryPathsFromVDF() {
        let paths = SteamDetector.libraryPaths(fromVDFText: sampleVDF)
        #expect(paths.contains("/Users/tester/Library/Application Support/Steam"))
        #expect(paths.contains("/Volumes/Games/SteamLibrary"))
        #expect(paths.count == 2)
    }

    @Test func parsesInstallDirFromManifest() {
        #expect(SteamDetector.installDir(fromManifestText: sampleManifest) == "An Elder Scrolls Legend Battlespire")
    }

    @Test func returnsNilForManifestWithoutInstallDir() {
        #expect(SteamDetector.installDir(fromManifestText: "\"AppState\" { \"appid\" \"1812420\" }") == nil)
    }

    @Test func findsGameDirectoryOnSecondaryLibrary() {
        let home = "/Users/tester"
        let defaultManifestPath = "\(home)/Library/Application Support/Steam/steamapps/appmanifest_1812420.acf"
        let secondaryManifestPath = "/Volumes/Games/SteamLibrary/steamapps/appmanifest_1812420.acf"
        let vdfPath = "\(home)/Library/Application Support/Steam/steamapps/libraryfolders.vdf"
        let gameExe = "/Volumes/Games/SteamLibrary/steamapps/common/An Elder Scrolls Legend Battlespire/GAME.EXE"

        let provider = FakeFileProvider(
            files: [
                vdfPath: sampleVDF,
                secondaryManifestPath: sampleManifest,
            ],
            existingPaths: [gameExe]
        )
        // No manifest at the default library, so the default-library lookup
        // is expected to miss and fall through to the secondary library.
        #expect(provider.stringContents(atPath: defaultManifestPath) == nil)

        let found = SteamDetector.findGameDirectory(homeDirectory: home, fileProvider: provider)
        #expect(found == "/Volumes/Games/SteamLibrary/steamapps/common/An Elder Scrolls Legend Battlespire")
    }

    @Test func returnsNilWhenNothingInstalled() {
        let provider = FakeFileProvider()
        #expect(SteamDetector.findGameDirectory(homeDirectory: "/Users/nobody", fileProvider: provider) == nil)
    }

    @Test func returnsNilWhenManifestExistsButGameExeMissing() {
        let home = "/Users/tester"
        let manifestPath = "\(home)/Library/Application Support/Steam/steamapps/appmanifest_1812420.acf"
        let provider = FakeFileProvider(files: [manifestPath: sampleManifest], existingPaths: [])
        #expect(SteamDetector.findGameDirectory(homeDirectory: home, fileProvider: provider) == nil)
    }
}
