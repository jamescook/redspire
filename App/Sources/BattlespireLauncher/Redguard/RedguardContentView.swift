import SwiftUI

/// Redguard's own content view, parallel to Battlespire's ContentView --
/// guided setup lives in RedguardOnboardingWizard (opened via "Setup
/// Wizard…" below), this just shows current state and launches the game.
struct RedguardContentView: View {
    @AppStorage("redguardGameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("redguardCdImagePath") private var cdImagePath = ""
    @AppStorage("redguardFullscreen") private var fullscreen = false
    @AppStorage("redguardBackend") private var backendRaw = Backend.staging.rawValue
    // Matches GOG's own dosbox_redguard.conf (memsize=63) -- Redguard's
    // Voodoo/3D pipeline is heavier than Battlespire's, confirmed during
    // the manual smoke test that first got this game running.
    @AppStorage("redguardMemsizeMB") private var memsizeMB = 63

    @ObservedObject var session: RedguardGameSession
    @Environment(\.openWindow) private var openWindow
    // installLooksComplete reads files on disk directly, but SwiftUI only
    // re-renders when a tracked @State/@AppStorage value actually *changes*
    // -- if the wizard finishes an install without gameDirectoryPath's
    // string value changing, nothing signals SwiftUI to recompute it.
    // Bumping this on refocus (e.g. after closing the wizard) forces that
    // section to redraw fresh. Same pattern as Battlespire's ContentView.
    @State private var refreshToken = UUID()

    private var backend: Backend {
        Backend(rawValue: backendRaw) ?? .staging
    }

    private var installLooksComplete: Bool {
        RedguardInstallCheck.looksComplete(gameDir: gameDirectoryPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                BrandIcon.image(fileName: GameMode.redguard.iconFileName, systemImageFallback: GameMode.redguard.systemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                Text("Redguard Launcher")
                    .font(.title2).bold()
            }

            GroupBox("Game Folder") {
                HStack {
                    Text(gameDirectoryPath.isEmpty ? "Not set" : gameDirectoryPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(gameDirectoryPath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Choose…") { chooseFolder() }
                    Button("Setup Wizard…") {
                        // Otherwise a stale error from a previous failed
                        // Play attempt keeps showing here even after the
                        // wizard fixes the underlying problem -- nothing
                        // else ever clears it.
                        session.lastError = nil
                        openWindow(id: "redguard-onboarding-wizard")
                    }
                }
                if installLooksComplete {
                    Label("Install looks complete", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .id(refreshToken)

            GroupBox("Second Disc (videos & music)") {
                HStack {
                    Text(cdImagePath.isEmpty ? "Not set — auto-detected in the game folder if present" : cdImagePath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose…") { chooseCDImage() }
                    if !cdImagePath.isEmpty {
                        Button("Clear") { cdImagePath = "" }
                    }
                }
            }

            GroupBox("DOSBox") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Backend", selection: $backendRaw) {
                        ForEach(Backend.allCases) { b in
                            Text(b.displayName).tag(b.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if backend.isInstalled {
                        Label("\(backend.displayName) installed", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    } else {
                        Label("\(backend.displayName) not found", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }

                    Toggle("Fullscreen", isOn: $fullscreen)
                    Stepper("Memory: \(memsizeMB) MB", value: $memsizeMB, in: 16...256, step: 16)
                }
            }

            if let error = session.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Circle()
                    .fill(session.isRunning ? .green : .gray)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(session.isRunning ? "Running" : "Not running")
                    .foregroundStyle(.secondary)
                Spacer()
                if session.isRunning {
                    Button("Quit Game") { session.quit() }
                } else {
                    Button("Play") { play() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(gameDirectoryPath.isEmpty || !backend.isInstalled)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshToken = UUID()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the folder containing the Redguard subfolder and game.ins"
        if let url = gameDirectoryPath.isEmpty ? nil : URL(fileURLWithPath: gameDirectoryPath) {
            panel.directoryURL = url
        }
        if panel.runModal() == .OK, let url = panel.url {
            gameDirectoryPath = url.path
        }
    }

    private func chooseCDImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select a CD image (.iso / .ins / .cue)"
        if panel.runModal() == .OK, let url = panel.url {
            cdImagePath = url.path
        }
    }

    private func play() {
        session.play(
            gameDir: gameDirectoryPath,
            cdImagePathOverride: cdImagePath,
            backend: backend,
            fullscreen: fullscreen,
            memsizeMB: memsizeMB
        )
    }
}
