import Foundation

/// A running async process, for cancellation.
protocol ProcessHandle {
    func terminate()
}

/// Seam over process-spawning so GogInstaller/BrewInstaller can be unit
/// tested with a fake instead of a real innoextract/brew binary.
protocol ProcessRunning {
    /// Runs to completion synchronously, capturing combined stdout+stderr.
    /// Used for quick preflight checks (e.g. `innoextract -l`).
    func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String)

    /// Runs asynchronously, streaming output as it arrives and reporting the
    /// exit code on completion. Used for long-running work (extraction,
    /// `brew install`) so the caller never blocks its thread on it.
    @discardableResult
    func runAsync(
        executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) -> ProcessHandle
}

private struct RealProcessHandle: ProcessHandle {
    let process: Process
    func terminate() { process.terminate() }
}

final class SystemProcessRunner: ProcessRunning {
    func runSync(executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
        } catch {
            return (-1, "Failed to run \(executable): \(error.localizedDescription)")
        }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (proc.terminationStatus, output)
    }

    @discardableResult
    func runAsync(
        executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) -> ProcessHandle {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let text = String(data: data, encoding: .utf8) {
                onOutput(text)
            }
        }

        proc.terminationHandler = { process in
            pipe.fileHandleForReading.readabilityHandler = nil
            ProcessRegistry.shared.unregister(process)
            onExit(process.terminationStatus)
        }

        do {
            try proc.run()
            ProcessRegistry.shared.register(proc)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            onOutput("Failed to run \(executable): \(error.localizedDescription)\n")
            onExit(-1)
        }

        return RealProcessHandle(process: proc)
    }
}
