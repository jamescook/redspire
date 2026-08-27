import Foundation

/// Mounts/unmounts a disc image via hdiutil. Shared between Battlespire's
/// and Redguard's disc-image installers -- neither game's specifics belong
/// here, it's just the mount plumbing both need.
enum DiscMounter {
    enum MountError: LocalizedError {
        case mountFailed(String)

        var errorDescription: String? {
            switch self {
            case .mountFailed(let reason):
                return "Couldn't open that disc image: \(reason)"
            }
        }
    }

    /// Pure: pulls the mount point out of `hdiutil attach -plist`'s output.
    static func parseMountPoint(fromHdiutilPlistOutput output: String) -> String? {
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else {
            return nil
        }
        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    static func mount(_ isoPath: String, runner: ProcessRunning) throws -> String {
        let result = runner.runSync(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", "-nobrowse", "-readonly", "-plist", isoPath]
        )
        guard result.exitCode == 0 else {
            throw MountError.mountFailed("hdiutil exited with status \(result.exitCode)")
        }
        guard let mountPoint = parseMountPoint(fromHdiutilPlistOutput: result.output) else {
            throw MountError.mountFailed("no mountable volume found in that image")
        }
        return mountPoint
    }

    static func unmount(_ mountPoint: String, runner: ProcessRunning) {
        _ = runner.runSync(executable: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-quiet"])
    }
}
