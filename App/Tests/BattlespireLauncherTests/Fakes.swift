import Foundation
@testable import BattlespireLauncher

/// FakeProcessRunner invokes its callbacks synchronously and in-line, so
/// tests that don't themselves hop actors (e.g. BrewInstaller, which isn't
/// @MainActor) can assert immediately after calling into the code under test
/// with no waiting/polling needed.
final class FakeProcessRunner: ProcessRunning {
    var syncResult: (exitCode: Int32, output: String) = (0, "")
    var asyncOutputLines: [String] = []
    var asyncExitCode: Int32 = 0

    private(set) var syncCalls: [(executable: String, arguments: [String])] = []
    private(set) var asyncCalls: [(executable: String, arguments: [String])] = []
    private(set) var lastHandle: FakeProcessHandle?

    func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
        syncCalls.append((executable, arguments))
        return syncResult
    }

    @discardableResult
    func runAsync(
        executable: String,
        arguments: [String],
        onOutput: @escaping (String) -> Void,
        onExit: @escaping (Int32) -> Void
    ) -> ProcessHandle {
        asyncCalls.append((executable, arguments))
        let handle = FakeProcessHandle()
        lastHandle = handle
        for line in asyncOutputLines { onOutput(line) }
        onExit(asyncExitCode)
        return handle
    }
}

final class FakeProcessHandle: ProcessHandle {
    private(set) var terminated = false
    func terminate() { terminated = true }
}

/// In-memory stand-in for SteamDetector's two disk reads.
struct FakeFileProvider: FileProviding {
    var files: [String: String] = [:]
    var existingPaths: Set<String> = []

    func stringContents(atPath path: String) -> String? { files[path] }
    func fileExists(atPath path: String) -> Bool { existingPaths.contains(path) }
}
