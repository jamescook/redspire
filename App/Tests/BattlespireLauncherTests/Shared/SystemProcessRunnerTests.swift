import Testing
import Foundation
@testable import Redspire

struct SystemProcessRunnerTests {
    @Test func runSyncDoesNotDeadlockWhenChildWritesMoreThanThePipeBuffer() {
        // Regression test for the classic Process+Pipe deadlock: if runSync
        // waits for the child to exit BEFORE draining its stdout pipe, a
        // child that writes more than the pipe's ~64KB kernel buffer before
        // exiting blocks forever on write() while we block forever in
        // waitUntilExit() -- neither side can proceed. `yes | head -c
        // 200000` reliably produces more than 64KB of stdout.
        let semaphore = DispatchSemaphore(value: 0)
        // Safe despite the mutation happening on another thread: the
        // semaphore below is a full happens-before barrier, it's just one
        // the compiler's Sendable checking can't see.
        nonisolated(unsafe) var result: (exitCode: Int32, output: String)?

        DispatchQueue.global().async {
            let runner = SystemProcessRunner()
            result = runner.runSync(executable: "/bin/sh", arguments: ["-c", "yes | head -c 200000"])
            semaphore.signal()
        }

        let timedOut = semaphore.wait(timeout: .now() + 10) == .timedOut
        #expect(!timedOut, "runSync did not return within 10 seconds -- likely deadlocked")
        #expect(result?.exitCode == 0)
        #expect(result?.output.utf8.count == 200_000)
    }
}
