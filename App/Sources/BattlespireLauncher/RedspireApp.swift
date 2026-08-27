import SwiftUI

/// Ensures any in-flight child process (steamcmd, innoextract) gets killed
/// before the app actually quits -- without this, ⌘Q/Quit leaves them
/// running as orphans (confirmed via `ps`; Foundation's Process doesn't do
/// this automatically when its Swift wrapper is deallocated).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Two instances writing to the same install destinations, or two
        // DOSBox sessions launched from the same wizard state, causes real
        // confusion -- LSMultipleInstancesProhibited in Info.plist covers
        // launches via `open`/Finder, but not running the binary inside
        // Contents/MacOS directly, which is how this app gets launched
        // during its own development. This check covers that gap with an
        // explicit, visible message instead of silently allowing it.
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jamescook.Redspire"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            let alert = NSAlert()
            alert.messageText = "Redspire is already running"
            alert.informativeText = "Only one copy can run at a time. Switching to the window that's already open."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }

        // One-time: carry over installs/extractions from before the app
        // was renamed from BattlespireLauncher to Redspire.
        AppSupportDirectory.migrateFromLegacyNameIfNeeded()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ProcessRegistry.shared.terminateAll()
        return .terminateNow
    }
}

@main
struct RedspireApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowResizability(.contentSize)
        // WindowGroup gets a "New Window" (Cmd+N) File menu command for
        // free -- makes no sense here, a second window would just be a
        // disconnected duplicate of the same single-window launcher, not a
        // useful new document/tab. Removing the whole "New Item" group.
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // A genuinely separate window rather than a .sheet, so it doesn't
        // compete with system panels (Passwords, AutoFill providers) for
        // key-window status the way sheet-modality can.
        Window("Setup Wizard", id: "onboarding-wizard") {
            OnboardingWizard()
        }
        .windowResizability(.contentSize)

        Window("Redguard Setup Wizard", id: "redguard-onboarding-wizard") {
            RedguardOnboardingWizard()
        }
        .windowResizability(.contentSize)
    }
}
