import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// A running interactive process -- can be sent lines on its stdin, or
/// terminated. Used for steamcmd, which prompts for a password (and
/// sometimes a Steam Guard code) on stdin during login.
protocol InteractiveProcessHandle: AnyObject {
    func sendLine(_ text: String)
    func terminate()
}

/// Seam over interactive process-spawning, mirroring ProcessRunning but with
/// stdin access, so SteamCMDSession can be unit tested with a fake instead
/// of a real steamcmd binary.
protocol InteractiveProcessRunning {
    @discardableResult
    func start(
        executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) -> InteractiveProcessHandle
}

private final class RealInteractiveProcessHandle: InteractiveProcessHandle {
    private let process: Process
    private let masterHandle: FileHandle

    init(process: Process, masterHandle: FileHandle) {
        self.process = process
        self.masterHandle = masterHandle
    }

    func sendLine(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        masterHandle.write(data)
    }

    func terminate() {
        process.terminate()
    }
}

enum PTYError: Error {
    case openptyFailed
}

/// Allocates a real pseudo-terminal for the child rather than a plain Pipe
/// (or shelling through `script`, which was tried and dropped -- routing
/// stdin through an extra relay process turned out not to reliably deliver
/// bytes written before the child was fully attached). Owning the PTY
/// master fd directly gives two things a plain Pipe can't: steamcmd sees a
/// real TTY and line-buffers instead of block-buffering (prompts arrive
/// live, not in a delayed burst), and writes to the master are queued by
/// the kernel's tty driver, reliably delivered once the child actually
/// reads, with no intermediary process to lose them.
final class SystemInteractiveProcessRunner: InteractiveProcessRunning {
    @discardableResult
    func start(
        executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) -> InteractiveProcessHandle {
        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1
        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            onOutput("Failed to allocate a pseudo-terminal for \(executable).\n")
            onExit(-1)
            return RealInteractiveProcessHandle(process: Process(), masterHandle: FileHandle.nullDevice)
        }

        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle

        masterHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let text = String(data: data, encoding: .utf8) {
                onOutput(text)
            }
        }

        proc.terminationHandler = { process in
            masterHandle.readabilityHandler = nil
            ProcessRegistry.shared.unregister(process)
            onExit(process.terminationStatus)
        }

        do {
            try proc.run()
            ProcessRegistry.shared.register(proc)
            // Only the child needs the slave side; holding our own copy
            // open would keep the master's read end from ever seeing EOF.
            try? slaveHandle.close()
        } catch {
            masterHandle.readabilityHandler = nil
            onOutput("Failed to run \(executable): \(error.localizedDescription)\n")
            onExit(-1)
        }

        return RealInteractiveProcessHandle(process: proc, masterHandle: masterHandle)
    }
}
