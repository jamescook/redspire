import Foundation
@testable import Redspire

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

/// Mirrors FakeProcessRunner for the interactive (stdin-capable) seam.
final class FakeInteractiveProcessRunner: InteractiveProcessRunning {
    var outputLines: [String] = []
    var exitCode: Int32 = 0

    private(set) var calls: [(executable: String, arguments: [String])] = []
    private(set) var sentLines: [String] = []
    private(set) var lastHandle: FakeInteractiveProcessHandle?

    @discardableResult
    func start(
        executable: String,
        arguments: [String],
        onOutput: @escaping (String) -> Void,
        onExit: @escaping (Int32) -> Void
    ) -> InteractiveProcessHandle {
        calls.append((executable, arguments))
        let handle = FakeInteractiveProcessHandle(onSend: { [weak self] line in self?.sentLines.append(line) })
        lastHandle = handle
        for line in outputLines { onOutput(line) }
        onExit(exitCode)
        return handle
    }
}

final class FakeInteractiveProcessHandle: InteractiveProcessHandle {
    private(set) var terminated = false
    private let onSend: (String) -> Void

    init(onSend: @escaping (String) -> Void) {
        self.onSend = onSend
    }

    func sendLine(_ text: String) { onSend(text) }
    func terminate() { terminated = true }
}

/// In-memory stand-in for the real Keychain-backed CredentialStore.
final class FakeCredentialStore: CredentialStore {
    private var storage: [String: String] = [:]
    private(set) var saveCalls: [(password: String, account: String)] = []
    private(set) var deleteCalls: [String] = []

    func listAccounts() -> [String] { storage.keys.sorted() }
    func password(for account: String) -> String? { storage[account] }

    @discardableResult
    func save(password: String, for account: String) -> Bool {
        saveCalls.append((password, account))
        storage[account] = password
        return true
    }

    @discardableResult
    func delete(account: String) -> Bool {
        deleteCalls.append(account)
        storage.removeValue(forKey: account)
        return true
    }
}

/// In-memory stand-in for SteamDetector's two disk reads.
struct FakeFileProvider: FileProviding {
    var files: [String: String] = [:]
    var existingPaths: Set<String> = []

    func stringContents(atPath path: String) -> String? { files[path] }
    func fileExists(atPath path: String) -> Bool { existingPaths.contains(path) }
}

/// @MainActor installers (GogInstaller, RedguardGogInstaller,
/// RedguardDiscImageInstaller, SteamCMDSession) wrap their process
/// callbacks in `Task { @MainActor in ... }`, since the real runner invokes
/// them off-MainActor -- correct for production, but it means even a
/// synchronous FakeProcessRunner's callbacks land on the MainActor queue
/// rather than updating @Published state inline. Call this after driving
/// one of those through a fake runner and before asserting on its state.
@MainActor
func drainMainActorTasks() async {
    for _ in 0..<20 { await Task.yield() }
}
