import SwiftUI

extension Notification.Name {
    /// Posted by the File menu's "Reset to Defaults…" command; RootView
    /// listens and shows the actual confirmation (menu commands can't
    /// present a SwiftUI .alert directly, they're not part of a View).
    static let requestResetToDefaults = Notification.Name("requestResetToDefaults")

    /// Posted by the WindowGroup's .onOpenURL handler after parsing a
    /// `redspire://launch/<mode>` URL (see DirectLaunchURL and
    /// DesktopShortcutCreator); RootView listens and drives that mode's
    /// session directly. The GameMode is passed as the notification's
    /// object.
    static let requestDirectLaunch = Notification.Name("requestDirectLaunch")
}

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

    /// RootView's direct-launch flow (see RootView.directLaunch) looks this
    /// window up by title to miniaturize it -- NSApp.keyWindow isn't
    /// reliably this window at the moment a direct-launch URL arrives while
    /// the app was already running in the background (confirmed live: it
    /// silently failed to hide the window in that exact case).
    static let mainWindowTitle = "Redspire"

    var body: some Scene {
        // Window (singular), not WindowGroup: WindowGroup can spawn a
        // SECOND window -- with its own independent GameSession -- when a
        // direct-launch URL arrives while the app is already running,
        // rather than delivering .onOpenURL to the existing one. Real bug
        // found live via the Desktop shortcut. Window guarantees exactly
        // one instance of this scene ever exists, matching the two wizard
        // windows below, which never had this problem for the same reason.
        Window(Self.mainWindowTitle, id: "main") {
            RootView()
                // Fired by double-clicking a Desktop shortcut (a tiny stub
                // app that just reopens this same app via this URL -- see
                // DesktopShortcutCreator). Posting a notification rather
                // than handling it here directly, since RootView owns the
                // actual GameSession/RedguardGameSession instances this
                // needs to drive.
                .onOpenURL { url in
                    if let mode = DirectLaunchURL.parse(url) {
                        NotificationCenter.default.post(name: .requestDirectLaunch, object: mode)
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Reset to Defaults…") {
                    NotificationCenter.default.post(name: .requestResetToDefaults, object: nil)
                }
            }
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
