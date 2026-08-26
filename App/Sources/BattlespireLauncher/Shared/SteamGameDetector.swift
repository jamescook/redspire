import Foundation

/// Finds an existing Steam install of a given AppID without needing
/// steamcmd or the user typing anything. Parses just enough of Valve's VDF
/// (KeyValues) text format with regexes -- proportionate for pulling two
/// field values out of two small config files, rather than pulling in a
/// full VDF parser for it. Shared between Battlespire's and Redguard's
/// detectors -- only the AppID and the exe path to verify differ.
enum SteamGameDetector {
    static func findGameDirectory(
        appID: String,
        exeRelativePath: String,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        fileProvider: FileProviding = RealFileProvider()
    ) -> String? {
        for library in candidateLibraryPaths(homeDirectory: homeDirectory, fileProvider: fileProvider) {
            let manifest = (library as NSString).appendingPathComponent("steamapps/appmanifest_\(appID).acf")
            guard let manifestText = fileProvider.stringContents(atPath: manifest) else { continue }
            guard let dir = installDir(fromManifestText: manifestText) else { continue }

            let gameDir = (library as NSString)
                .appendingPathComponent("steamapps/common")
                .appending("/\(dir)")
            let exePath = (gameDir as NSString).appendingPathComponent(exeRelativePath)
            if fileProvider.fileExists(atPath: exePath) {
                return gameDir
            }
        }
        return nil
    }

    private static func candidateLibraryPaths(homeDirectory: String, fileProvider: FileProviding) -> [String] {
        let defaultLibrary = "\(homeDirectory)/Library/Application Support/Steam"
        var paths: Set<String> = [defaultLibrary]

        let libraryFoldersVDF = "\(defaultLibrary)/steamapps/libraryfolders.vdf"
        if let text = fileProvider.stringContents(atPath: libraryFoldersVDF) {
            paths.formUnion(libraryPaths(fromVDFText: text))
        }
        return Array(paths)
    }

    /// Pure: extracts every `"path"  "..."` value from libraryfolders.vdf's
    /// text. Testable with a literal VDF fixture, no real Steam install needed.
    static func libraryPaths(fromVDFText text: String) -> [String] {
        allMatches(pattern: #""path"\s+"([^"]+)""#, in: text)
            .map { $0.replacingOccurrences(of: "\\\\", with: "/") }
    }

    /// Pure: extracts `"installdir"  "..."` from an appmanifest_<id>.acf's text.
    static func installDir(fromManifestText text: String) -> String? {
        allMatches(pattern: #""installdir"\s+"([^"]+)""#, in: text).first
    }

    private static func allMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }
}
