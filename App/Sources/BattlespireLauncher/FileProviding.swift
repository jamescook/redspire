import Foundation

/// Seam over the two filesystem reads SteamDetector needs, so it can be
/// tested against in-memory fixtures instead of a real ~/Library/.../Steam.
protocol FileProviding {
    func stringContents(atPath path: String) -> String?
    func fileExists(atPath path: String) -> Bool
}

struct RealFileProvider: FileProviding {
    func stringContents(atPath path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
