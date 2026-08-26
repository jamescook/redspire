import SwiftUI
import UniformTypeIdentifiers

enum RedguardWizardScreen: Hashable {
    case chooseSource
    case gogGuide
}

/// Redguard's own setup wizard, mirroring OnboardingWizard's shape and
/// visual style for consistency. Only GOG and "I already have it installed"
/// are real options -- Steam support (battlespire-macos-ao9.4) isn't built
/// yet, so it's left out entirely rather than shown as a dead-end choice.
struct RedguardOnboardingWizard: View {
    @AppStorage("redguardGameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("redguardWizardCompleted") private var wizardCompleted = false
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var screen: RedguardWizardScreen = .chooseSource
    @State private var manualErrorMessage: String?
    @StateObject private var gogInstaller = RedguardGogInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch screen {
            case .chooseSource: chooseSourceView
            case .gogGuide: gogGuideView
            }
        }
        .padding(24)
        .frame(width: 520, height: 600, alignment: .top)
        .onAppear {
            // Singular Window(id:), not a WindowGroup -- see OnboardingWizard's
            // identical comment for why this reset is needed on reopen.
            screen = .chooseSource
            manualErrorMessage = nil
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
            ) { manualErrorMessage = nil; screen = .gogGuide }

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
