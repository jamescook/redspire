import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("gameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("cdImagePath") private var cdImagePath = ""
    @AppStorage("fullscreen") private var fullscreen = false
    @AppStorage("backend") private var backendRaw = Backend.staging.rawValue
    @AppStorage("memsizeMB") private var memsizeMB = 48
    @AppStorage("wizardCompleted") private var wizardCompleted = false

    @StateObject private var session = GameSession()
    @State private var installer = BrewInstaller()
    @State private var isInstalling = false
    @State private var installLog = ""
    @State private var showWizard = false

    private var backend: Backend {
        get { Backend(rawValue: backendRaw) ?? .staging }
    }

    private var versionWarning: String? {
        guard !gameDirectoryPath.isEmpty else { return nil }
        let exe = (gameDirectoryPath as NSString).appendingPathComponent("GAME.EXE")
        guard let v = GameVersion.detect(gameExePath: exe) else { return nil }
        return GameVersion.isV15(v) ? nil : "Detected \(v) — v1.3 is known-broken under DOSBox. See README for the v1.5 patch."
    }

    private var verifiedBuildBadge: Bool {
        guard !gameDirectoryPath.isEmpty else { return false }
        let exe = (gameDirectoryPath as NSString).appendingPathComponent("GAME.EXE")
        return KnownGoodBuilds.isVerified(gameExePath: exe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Battlespire Launcher")
                .font(.title2).bold()

            GroupBox("Game Folder") {
                HStack {
                    Text(gameDirectoryPath.isEmpty ? "Not set" : gameDirectoryPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(gameDirectoryPath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Choose…") { chooseFolder() }
                    Button("Setup Wizard…") { showWizard = true }
                }
                if let warning = versionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if verifiedBuildBadge {
                    Label("Matches a verified official v1.5 build", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            GroupBox("CD Image (optional)") {
                HStack {
                    Text(cdImagePath.isEmpty ? "Auto-detect game.ins in game folder" : cdImagePath)
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

                    HStack {
                        if backend.isInstalled {
                            Label("\(backend.displayName) installed", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        } else {
                            Label("\(backend.displayName) not found", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                            Spacer()
                            if backend == .staging, Backend.brewPath != nil {
                                Button(isInstalling ? "Installing…" : "Install via Homebrew") {
                                    install()
                                }
                                .disabled(isInstalling)
                            } else {
                                Button("Installation Instructions") {
                                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                                }
                            }
                        }
                    }

                    if !installLog.isEmpty {
                        ScrollView {
                            Text(installLog)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 80)
                        .background(Color.black.opacity(0.05))
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
        .onAppear {
            if !wizardCompleted { showWizard = true }
        }
        .sheet(isPresented: $showWizard) {
            OnboardingWizard(gameDirectoryPath: $gameDirectoryPath) {
                wizardCompleted = true
                showWizard = false
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the folder containing GAME.EXE"
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
        panel.allowedContentTypes = [UTType(filenameExtension: "iso"), UTType(filenameExtension: "ins")].compactMap { $0 }
        panel.prompt = "Select"
        panel.message = "Select a CD image (.iso / .ins)"
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

    private func install() {
        isInstalling = true
        installLog = ""
        installer.install(formula: "dosbox-staging", onOutput: { line in
            Task { @MainActor in installLog += line }
        }, onComplete: { success in
            Task { @MainActor in
                isInstalling = false
                installLog += success ? "\nDone.\n" : "\nInstall failed — see output above.\n"
            }
        })
    }
}
