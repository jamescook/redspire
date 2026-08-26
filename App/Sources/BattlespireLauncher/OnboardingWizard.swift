import SwiftUI
import UniformTypeIdentifiers

private enum WizardScreen {
    case chooseSource
    case steamGuide
    case gogGuide
}

struct OnboardingWizard: View {
    @Binding var gameDirectoryPath: String
    var onComplete: () -> Void

    @State private var screen: WizardScreen = .chooseSource
    @State private var detectedSteamPath: String?
    @State private var steamRedetectAttempted = false
    @StateObject private var gogInstaller = GogInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch screen {
            case .chooseSource: chooseSourceView
            case .steamGuide: steamGuideView
            case .gogGuide: gogGuideView
            }
        }
        .padding(24)
        .frame(width: 520, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            detectedSteamPath = SteamDetector.findGameDirectory()
        }
    }

    // MARK: - Choose source

    private var chooseSourceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Battlespire Launcher")
                .font(.title2).bold()
            Text("Let's find your copy of the game.")
                .foregroundStyle(.secondary)

            if let detected = detectedSteamPath {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Found an existing Steam install", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(detected)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Use This Copy") {
                            gameDirectoryPath = detected
                            onComplete()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text(detectedSteamPath == nil ? "How do you have the game?" : "Or set it up a different way:")
                .font(.headline)
                .padding(.top, 4)

            sourceCard(
                title: "Steam",
                subtitle: "I own it on Steam",
                systemImage: "gamecontroller"
            ) { screen = .steamGuide }

            sourceCard(
                title: "GOG",
                subtitle: "I bought it on GOG.com",
                systemImage: "arrow.down.circle"
            ) { screen = .gogGuide }

            sourceCard(
                title: "I already have it installed",
                subtitle: "Point me at an existing game folder",
                systemImage: "folder"
            ) { chooseExistingFolder() }
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

    private func chooseExistingFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the folder containing GAME.EXE"
        if panel.runModal() == .OK, let url = panel.url {
            gameDirectoryPath = url.path
            onComplete()
        }
    }

    // MARK: - Steam guide

    private var steamGuideView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton
            Text("Install via Steam").font(.title2).bold()
            Text("""
            Battlespire is on Steam (AppID 1812420, ~$6). Install it normally \
            through the Steam app, then come back here and click Detect Again.
            """)
            .fixedSize(horizontal: false, vertical: true)

            Button("Open Steam Store Page") {
                NSWorkspace.shared.open(URL(string: "https://store.steampowered.com/app/1812420")!)
            }

            Divider()

            Button("Detect Again") {
                steamRedetectAttempted = true
                if let found = SteamDetector.findGameDirectory() {
                    gameDirectoryPath = found
                    onComplete()
                }
            }
            .keyboardShortcut(.defaultAction)

            if steamRedetectAttempted && SteamDetector.findGameDirectory() == nil {
                Label("Still not found. Make sure the install finished, then try again.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - GOG guide

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

                Button("Open Battlespire on GOG.com") {
                    NSWorkspace.shared.open(URL(string: "https://www.gog.com/en/game/an_elder_scrolls_legend_battlespire")!)
                }
                .disabled(gogInstaller.isRunning)

                Divider()
            }

            gogInstallStatusView
        }
    }

    private var isExtractionDone: Bool {
        if case .done = gogInstaller.stage { return true }
        return false
    }

    @ViewBuilder
    private var gogInstallStatusView: some View {
        if !InnoExtractTool.isInstalled {
            innoExtractMissingView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                switch gogInstaller.stage {
                case .none:
                    Button("Browse for Installer (.exe)…") { browseForInstaller() }
                case .extracting:
                    statusRow(spinning: true, text: "Extracting… this can take a few minutes for a ~600MB installer.")
                case .verifying:
                    statusRow(spinning: true, text: "Verifying game files…")
                case .failed(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try Again") {
                        browseForInstaller()
                    }
                case .done(let dir, let verified):
                    installerOptionCard(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        text: verified
                            ? "Extracted successfully — matches a verified official v1.5 build."
                            : "Extracted successfully."
                    )
                    Button("Continue") {
                        gameDirectoryPath = dir
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if !gogInstaller.log.isEmpty {
                    logView
                }

                if gogInstaller.isRunning {
                    Button("Cancel") { gogInstaller.cancel() }
                }
            }
        }
    }

    private func statusRow(spinning: Bool, text: String) -> some View {
        HStack {
            if spinning { ProgressView().controlSize(.small) }
            Text(text)
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(gogInstaller.log)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("logEnd")
            }
            .frame(height: 140)
            .background(Color.black.opacity(0.05))
            .onChange(of: gogInstaller.log) { _ in
                proxy.scrollTo("logEnd", anchor: .bottom)
            }
        }
    }

    private var innoExtractMissingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("innoextract isn't installed — it's needed to unpack the GOG installer without running it.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            if Backend.brewPath != nil {
                Text("Run this in Terminal, then come back:").font(.caption).foregroundStyle(.secondary)
                Text("brew install innoextract")
                    .font(.system(.callout, design: .monospaced))
                    .padding(6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            } else {
                Text("Homebrew isn't installed either. Install it from brew.sh first, then run: brew install innoextract")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open brew.sh") {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
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

    private var backButton: some View {
        Button {
            screen = .chooseSource
        } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
