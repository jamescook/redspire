import Foundation

enum GameVersion {
    /// Mirrors `strings GAME.EXE | grep -im1 "battlespire v"`: scans for
    /// printable ASCII runs (matching `strings`' default min length of 4)
    /// containing "battlespire v", case-insensitively. Pure function of the
    /// bytes -- no disk access -- so it's testable with a small synthetic
    /// blob instead of a real GAME.EXE.
    static func detect(inBytes data: Data) -> String? {
        var run: [UInt8] = []
        var found: String?

        func flush() {
            guard found == nil, run.count >= 4 else { run.removeAll(); return }
            if let s = String(bytes: run, encoding: .ascii) {
                if let range = s.range(of: "battlespire v", options: .caseInsensitive) {
                    found = String(s[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
            run.removeAll()
        }

        for byte in data {
            if byte >= 0x20 && byte < 0x7F {
                run.append(byte)
            } else {
                flush()
                if found != nil { break }
            }
        }
        flush()
        return found
    }

    static func detect(gameExePath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: gameExePath) else { return nil }
        return detect(inBytes: data)
    }

    static func isV15(_ versionString: String?) -> Bool {
        guard let v = versionString else { return false }
        return v.uppercased().contains("V1.5")
    }
}
