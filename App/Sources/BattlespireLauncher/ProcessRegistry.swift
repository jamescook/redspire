import Foundation

/// Tracks every child process this app has spawned (innoextract, steamcmd,
/// brew), so they can all be terminated on app quit. `deinit` on the owning
/// session objects handles the "user closes just this window" case, but
/// isn't guaranteed to run before the process actually exits on ⌘Q/Quit --
/// this is the backstop for that, wired to applicationShouldTerminate.
final class ProcessRegistry: @unchecked Sendable {
    static let shared = ProcessRegistry()

    private let lock = NSLock()
    private var processes: [ObjectIdentifier: Process] = [:]

    private init() {}

    func register(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        processes[ObjectIdentifier(process)] = process
    }

    func unregister(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        processes.removeValue(forKey: ObjectIdentifier(process))
    }

    func terminateAll() {
        lock.lock()
        let running = processes.values.filter { $0.isRunning }
        lock.unlock()
        for process in running {
            process.terminate()
        }
    }
}
