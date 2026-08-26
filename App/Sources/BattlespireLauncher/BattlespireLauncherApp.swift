import SwiftUI

/// Ensures any in-flight child process (steamcmd, innoextract) gets killed
/// before the app actually quits -- without this, ⌘Q/Quit leaves them
/// running as orphans (confirmed via `ps`; Foundation's Process doesn't do
/// this automatically when its Swift wrapper is deallocated).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ProcessRegistry.shared.terminateAll()
        return .terminateNow
    }
}

@main
struct BattlespireLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)

        // A genuinely separate window rather than a .sheet, so it doesn't
        // compete with system panels (Passwords, AutoFill providers) for
        // key-window status the way sheet-modality can.
        Window("Setup Wizard", id: "onboarding-wizard") {
            OnboardingWizard()
        }
        .windowResizability(.contentSize)
    }
}
