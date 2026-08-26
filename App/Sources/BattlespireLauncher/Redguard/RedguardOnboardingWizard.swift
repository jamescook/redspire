import SwiftUI
import UniformTypeIdentifiers

enum RedguardWizardScreen: Hashable {
    case chooseSource
    case gogGuide
    case discImage
}

/// Redguard's own setup wizard, mirroring OnboardingWizard's shape and
/// visual style for consistency. GOG, the original disc(s), and "I already
/// have it installed" are the real options -- Steam support
/// (battlespire-macos-ao9.4) isn't built yet, so it's left out entirely
/// rather than shown as a dead-end choice.
struct RedguardOnboardingWizard: View {
    @AppStorage("redguardGameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("redguardCdImagePath") private var cdImagePath = ""
    @AppStorage("redguardWizardCompleted") private var wizardCompleted = false
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var screen: RedguardWizardScreen = .chooseSource
    @State private var manualErrorMessage: String?
    @State private var playDiscPath = ""
    @StateObject private var gogInstaller = RedguardGogInstaller()
    @StateObject private var discInstaller = RedguardDiscImageInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch screen {
            case .chooseSource: chooseSourceView
            case .gogGuide: gogGuideView
            case .discImage: discImageView
            }
        }
        .padding(24)
        .frame(width: 520, height: 600, alignment: .top)
        .onAppear {
            // Singular Window(id:), not a WindowGroup -- see OnboardingWizard's
            // identical comment for why this reset is needed on reopen.
            screen = .chooseSource
            manualErrorMessage = nil
            playDiscPath = ""
            gogInstaller.reset()
            discInstaller.reset()
        }
    }

    // MARK: - Choose source

    private var chooseSourceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Welcome to Redguard Launcher")
                    .font(.title2).bold()
                Spacer()
                Button("Cancel") { cancel() }
                    .keyboardShortcut(.cancelAction)
            }
            Text("Let's find your copy of the game.")
                .foregroundStyle(.secondary)

            Text("How do you have the game?")
                .font(.headline)
                .padding(.top, 4)

            sourceCard(
                title: "GOG",
                subtitle: "I bought it on GOG.com",
                systemImage: "arrow.down.circle"
            ) { manualErrorMessage = nil; gogInstaller.reset(); screen = .gogGuide }

            sourceCard(
                title: "I have the original disc(s)",
                subtitle: "Extract from a ripped install-disc image (.iso)",
                systemImage: "opticaldiscdrive"
            ) { manualErrorMessage = nil; playDiscPath = ""; discInstaller.reset(); screen = .discImage }

            sourceCard(
                title: "I already have it installed",
                subtitle: "Point me at an existing Redguard install folder",
                systemImage: "folder"
            ) { chooseExistingFolder() }

            if let manualErrorMessage {
                Label(manualErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceCard(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 32)
                VStack(alignment: .leading) {
                    Text(title).bold()
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    private func chooseExistingFolder() {
        manualErrorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the folder containing a Redguard subfolder and game.ins"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Redguard/REDGUARD.EXE").path) else {
            manualErrorMessage = "Couldn't find Redguard/REDGUARD.EXE in that folder -- pick the folder that has a Redguard subfolder directly inside it."
            return
        }

        gameDirectoryPath = url.path
        complete()
    }

    // MARK: - Install via GOG

    private var gogGuideView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !gogInstaller.isRunning {
                backButton
            }
            Text("Install via GOG").font(.title2).bold()

            if !isExtractionDone {
                Text("""
                GOG's download page offers two different files — make sure you get \
                the right one:
                """)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    installerOptionCard(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        text: "The \"offline backup installer\" (100s of MB, named setup_*.exe) — this is the one you need."
                    )
                    installerOptionCard(
                        icon: "xmark.circle.fill",
                        color: .red,
                        text: "The small \"GOG Galaxy\" web installer (a few hundred KB) — won't work here."
                    )
                }

                Text("Look for the offline installer under a dropdown near GOG's main download button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open Redguard on GOG.com") {
                    NSWorkspace.shared.open(URL(string: "https://www.gog.com/en/game/the_elder_scrolls_adventures_redguard")!)
                }
                .disabled(gogInstaller.isRunning)

                Divider()
            }

            gogInstallStatusView
        }
    }

    private func installerOptionCard(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color, lineWidth: 4)
        )
    }

    private var isExtractionDone: Bool {
        if case .done = gogInstaller.stage { return true }
        return false
    }

    @ViewBuilder
    private var gogInstallStatusView: some View {
        if !InnoExtractTool.isInstalled {
            MissingHomebrewToolView(
                toolName: "innoextract",
                reason: "it's needed to unpack the GOG installer without running it",
                formula: "innoextract"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                switch gogInstaller.stage {
                case .none:
                    Button("Browse for Installer (.exe)…") { browseForInstaller() }
                case .extracting:
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Extracting… this can take a few minutes for a ~900MB installer.")
                    }
                case .failed(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try Again") { browseForInstaller() }
                case .done(let dir):
                    installerOptionCard(icon: "checkmark.circle.fill", color: .green, text: "Extracted successfully.")
                    Button("Continue") {
                        gameDirectoryPath = dir
                        complete()
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if !gogInstaller.log.isEmpty {
                    LogScrollView(text: gogInstaller.log)
                }

                if gogInstaller.isRunning {
                    Button("Cancel") { gogInstaller.cancel() }
                }
            }
        }
    }

    private func browseForInstaller() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe")].compactMap { $0 }
        panel.prompt = "Select"
        panel.message = "Select the GOG offline installer (setup_*.exe)"
        if panel.runModal() == .OK, let url = panel.url {
            gogInstaller.extract(installerPath: url.path)
        }
    }

    // MARK: - Install from disc image

    private var discImageView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !discInstaller.isRunning {
                backButton
            }
            Text("Install from Disc Image").font(.title2).bold()

            if discInstaller.stage == nil {
                Text("Point this at a ripped copy of Disc 1 (the Install Disc) as a .iso file. If you haven't ripped it yet, ripping tools like bchunk can pull one off the physical disc.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            discInstallStatusView
        }
    }

    @ViewBuilder
    private var discInstallStatusView: some View {
        if !UnshieldTool.isInstalled {
            MissingHomebrewToolView(
                toolName: "unshield",
                reason: "the retail disc's installer is an InstallShield package that needs it to unpack without running Windows",
                formula: "unshield"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                switch discInstaller.stage {
                case .none:
                    Button("Choose Disc 1 Image (.iso)…") { browseForDiscImage() }
                case .extracting:
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Extracting…")
                    }
                case .needsGlideDriver:
                    glideDriverPrompt
                case .failed(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try Again") { browseForDiscImage() }
                case .done(let dir):
                    installerOptionCard(icon: "checkmark.circle.fill", color: .green, text: "Extracted successfully.")
                    playDiscPrompt
                    Button("Continue") {
                        gameDirectoryPath = dir
                        if !playDiscPath.isEmpty { cdImagePath = playDiscPath }
                        complete()
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if !discInstaller.log.isEmpty {
                    LogScrollView(text: discInstaller.log)
                }

                if discInstaller.isRunning {
                    Button("Cancel") { discInstaller.cancel() }
                }
            }
        }
    }

    @ViewBuilder
    private var glideDriverPrompt: some View {
        if case .needsGlideDriver(let gameDir) = discInstaller.stage {
            VStack(alignment: .leading, spacing: 10) {
                installerOptionCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    text: "Everything else is ready, but this game also needs a file called GLIDE2X.OVL that the retail disc doesn't include (a licensing thing, not a bug on our end)."
                )
                Text("If you also own this game on GOG, open that install's DOSBOX folder and pick glide2x_emu.ovl there. Otherwise, DOSBox-X's own guide explains where to find an official copy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Choose File…") { browseForGlideDriver(gameDir: gameDir) }
                    Button("Open DOSBox-X's Guide") {
                        NSWorkspace.shared.open(URL(string: "https://dosbox-x.com/wiki/Guide:Setting-up-3dfx-Voodoo-in-DOSBox%E2%80%90X")!)
                    }
                }
            }
        }
    }

    private var playDiscPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This game also plays its videos and music from its second disc while you're playing. Add that now so everything works, or add it later from the main screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(playDiscPath.isEmpty ? "Choose Second Disc…" : "Second Disc Selected") { browseForPlayDisc() }
                if !playDiscPath.isEmpty {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }

    private func browseForPlayDisc() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the second disc, ripped as an image file (.iso, .cue, or .ins)"
        if panel.runModal() == .OK, let url = panel.url {
            playDiscPath = url.path
        }
    }

    private func browseForDiscImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "iso")].compactMap { $0 }
        panel.prompt = "Select"
        panel.message = "Select Disc 1 (the Install Disc) as a .iso file"
        if panel.runModal() == .OK, let url = panel.url {
            discInstaller.extract(isoPath: url.path)
        }
    }

    private func browseForGlideDriver(gameDir: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select glide2x_emu.ovl (or another legitimate GLIDE2X.OVL)"
        if panel.runModal() == .OK, let url = panel.url {
            discInstaller.supplyGlideDriver(fromPath: url.path, gameDir: gameDir)
        }
    }

    private var backButton: some View {
        Button {
            screen = .chooseSource
        } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func complete() {
        wizardCompleted = true
        dismissWindow(id: "redguard-onboarding-wizard")
    }

    private func cancel() {
        dismissWindow(id: "redguard-onboarding-wizard")
    }
}
