import SwiftUI
import UniformTypeIdentifiers

enum WizardScreen: Hashable {
    case chooseSource
    case steamMethodChoice
    case steamViaApp
    case steamViaCommand
    case steamViaAutomatic
    case gogGuide
}

enum SteamInstallMethod: String, CaseIterable, Identifiable {
    case steamApp
    case runCommandMyself
    case letAppDoIt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steamApp: return "Install it via the Steam app"
        case .runCommandMyself: return "I'll run steamcmd myself"
        case .letAppDoIt: return "Let this app run steamcmd for me"
        }
    }

    var subtitle: String {
        switch self {
        case .steamApp: return "Normal install through Steam's own app, then we detect it"
        case .runCommandMyself: return "We give you the exact command; you run it in Terminal"
        case .letAppDoIt: return "Enter your Steam login here; it downloads automatically"
        }
    }

    var icon: String {
        switch self {
        case .steamApp: return "gamecontroller"
        case .runCommandMyself: return "terminal"
        case .letAppDoIt: return "bolt.fill"
        }
    }

    var screen: WizardScreen {
        switch self {
        case .steamApp: return .steamViaApp
        case .runCommandMyself: return .steamViaCommand
        case .letAppDoIt: return .steamViaAutomatic
        }
    }
}

struct OnboardingWizard: View {
    @AppStorage("gameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("wizardCompleted") private var wizardCompleted = false
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var screen: WizardScreen = .chooseSource
    @State private var selectedSteamMethod: SteamInstallMethod?
    @State private var detectedSteamPath: String?
    @State private var steamRedetectAttempted = false
    @State private var steamUsername = ""
    @State private var steamPassword = ""
    @State private var steamGuardCode = ""
    @State private var rememberPassword = false
    @State private var commandCopied = false
    @State private var savedAccounts: [String] = []
    @State private var selectedSavedAccount: String?
    @State private var savedPasswordUnavailable = false
    private let credentialStore: CredentialStore = KeychainCredentialStore()
    @StateObject private var gogInstaller = GogInstaller()
    @StateObject private var steamCMDSession = SteamCMDSession()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch screen {
            case .chooseSource: chooseSourceView
            case .steamMethodChoice: steamMethodChoiceView
            case .steamViaApp: steamViaAppView
            case .steamViaCommand: steamViaCommandView
            case .steamViaAutomatic: steamViaAutomaticView
            case .gogGuide: gogGuideView
            }
        }
        .padding(24)
        .frame(width: 520, height: 600, alignment: .top)
        .onAppear {
            // This is a singular Window(id:), not a WindowGroup -- closing
            // and reopening it reuses the same view/state rather than
            // constructing fresh, so without this it "remembers" whatever
            // screen was showing when it was last closed.
            screen = .chooseSource
            selectedSteamMethod = nil
            detectedSteamPath = SteamDetector.findGameDirectory()
            savedAccounts = credentialStore.listAccounts()
        }
        .onChange(of: steamCMDSession.stage) {
            savedAccounts = credentialStore.listAccounts()
        }
    }

    // MARK: - Choose source

    private var chooseSourceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Welcome to Battlespire Launcher")
                    .font(.title2).bold()
                Spacer()
                Button("Cancel") { cancel() }
                    .keyboardShortcut(.cancelAction)
            }
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
                            complete()
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
            ) { screen = .steamMethodChoice }

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
            complete()
        }
    }

    // MARK: - Steam: method choice

    private var steamMethodChoiceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton
            Text("How do you want to install it?").font(.title2).bold()
            Label("Battlespire doesn't appear to be installed via Steam yet.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(SteamInstallMethod.allCases) { method in
                    methodChoiceCard(method)
                }
            }

            if let selected = selectedSteamMethod {
                Button("Continue") { screen = selected.screen }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func methodChoiceCard(_ method: SteamInstallMethod) -> some View {
        let isSelected = selectedSteamMethod == method
        return Button {
            selectedSteamMethod = method
        } label: {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                Image(systemName: method.icon)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(method.title).bold()
                    Text(method.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
    }

    // MARK: - Steam: via the Steam app

    private var steamViaAppView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton(to: .steamMethodChoice)
            Text("Install via the Steam App").font(.title2).bold()
            Text("Install it normally through the Steam app -- Battlespire's AppID is 1812420.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Steam Store Page") {
                NSWorkspace.shared.open(URL(string: "https://store.steampowered.com/app/1812420")!)
            }

            Divider()

            manualDetectFooter
        }
    }

    // MARK: - Steam: run steamcmd myself

    private var steamViaCommandView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton(to: .steamMethodChoice)
            HStack(spacing: 4) {
                Text("Run steamcmd Yourself").font(.title2).bold()
                steamCMDTooltip
            }

            if !SteamCMDTool.isInstalled {
                missingHomebrewToolView(
                    toolName: "steamcmd",
                    reason: "it can download the game files directly, without installing the full Steam client",
                    formula: "steamcmd"
                )
            } else {
                Text("Enter your Steam username, then copy this command and run it in Terminal -- it'll prompt you for your password and Steam Guard code there.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Steam username", text: $steamUsername)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .frame(maxWidth: 240)
                Text(SteamCMDInstaller.command(username: steamUsername, destDir: SteamCMDInstaller.installDestination.path))
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
                    .textSelection(.enabled)
                HStack {
                    Button(commandCopied ? "Copied!" : "Copy Command") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(SteamCMDInstaller.command(username: steamUsername, destDir: SteamCMDInstaller.installDestination.path), forType: .string)
                        commandCopied = true
                    }
                    Button("Open Terminal") { openTerminal() }
                }
            }

            Divider()

            manualDetectFooter
        }
    }

    // MARK: - Steam: let the app do it

    private var steamViaAutomaticView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !steamCMDSession.isRunning {
                backButton(to: .steamMethodChoice)
            }
            HStack(spacing: 4) {
                Text("Automatic Install").font(.title2).bold()
                steamCMDTooltip
            }

            if !SteamCMDTool.isInstalled {
                missingHomebrewToolView(
                    toolName: "steamcmd",
                    reason: "it can download the game files directly, without installing the full Steam client",
                    formula: "steamcmd"
                )
            } else if steamCMDSession.stage != nil {
                steamCMDSessionView
            } else {
                if !savedAccounts.isEmpty {
                    savedAccountPicker
                }
                if selectedSavedAccount == nil {
                    TextField("Steam username", text: $steamUsername)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .frame(maxWidth: 240)
                }

                if selectedSavedAccount != nil {
                    Label("Using the saved password for this account.", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Password and Steam Guard code stay local to this steamcmd process.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NativeSecureField(placeholder: "Steam password", text: $steamPassword)
                        .frame(maxWidth: 200, maxHeight: 22)
                    Toggle("Remember this password in Keychain", isOn: $rememberPassword)
                        .font(.caption)
                }
                Button("Run for Me") {
                    steamCMDSession.start(
                        username: steamUsername,
                        password: steamPassword,
                        destDir: SteamCMDInstaller.installDestination.path,
                        rememberPassword: rememberPassword
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(steamUsername.trimmingCharacters(in: .whitespaces).isEmpty || steamPassword.isEmpty)
            }
        }
    }

    private var steamCMDTooltip: InfoTooltip {
        InfoTooltip(
            text: "steamcmd is Valve's official command-line tool for downloading Steam games without the full Steam app — handy for headless/automated installs.",
            linkURL: URL(string: "https://developer.valvesoftware.com/wiki/SteamCMD")!
        )
    }

    private var manualDetectFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("I've Installed It — Detect Again") {
                steamRedetectAttempted = true
                if let found = SteamDetector.findGameDirectory() ?? SteamCMDInstaller.findInstalledGameDir() {
                    gameDirectoryPath = found
                    complete()
                }
            }
            .keyboardShortcut(.defaultAction)

            if steamRedetectAttempted && SteamDetector.findGameDirectory() == nil && SteamCMDInstaller.findInstalledGameDir() == nil {
                Label("Still not found. Make sure the install finished, then try again.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var savedAccountPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Saved account", selection: $selectedSavedAccount) {
                Text("Use a different account").tag(String?.none)
                ForEach(savedAccounts, id: \.self) { account in
                    Text(account).tag(String?.some(account))
                }
            }
            .frame(maxWidth: 280)
            .onChange(of: selectedSavedAccount) { _, newValue in
                guard let account = newValue else {
                    steamUsername = ""
                    steamPassword = ""
                    return
                }
                steamUsername = account
                if let saved = credentialStore.password(for: account) {
                    steamPassword = saved
                } else {
                    // Deleted from Keychain outside the app, access denied, etc.
                    // Fall back to manual entry rather than a silently-stuck button.
                    savedPasswordUnavailable = true
                    selectedSavedAccount = nil
                    steamPassword = ""
                }
            }

            if savedPasswordUnavailable {
                Label("Saved password unavailable — enter it again below.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let account = selectedSavedAccount {
                Button("Forget This Account", role: .destructive) {
                    credentialStore.delete(account: account)
                    savedAccounts.removeAll { $0 == account }
                    selectedSavedAccount = nil
                    steamUsername = ""
                    steamPassword = ""
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var steamCMDSessionView: some View {
        switch steamCMDSession.stage {
        case .running:
            HStack {
                ProgressView().controlSize(.small)
                Text("Running steamcmd…")
            }
            if steamCMDSession.log.localizedCaseInsensitiveContains("confirm the login in the Steam Mobile app") {
                Label("Check your phone — approve this sign-in in the Steam Mobile app.", systemImage: "iphone")
                    .foregroundStyle(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LogScrollView(text: steamCMDSession.log)
            HStack {
                TextField("Steam Guard code (if asked)", text: $steamGuardCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Button("Send") {
                    steamCMDSession.send(steamGuardCode)
                    steamGuardCode = ""
                }
                .disabled(steamGuardCode.isEmpty)
            }
            Button("Cancel") { steamCMDSession.cancel() }
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            LogScrollView(text: steamCMDSession.log)
            Button("Try Again") { steamCMDSession.reset() }
        case .done(let dir):
            installerOptionCard(icon: "checkmark.circle.fill", color: .green, text: "Downloaded successfully via steamcmd.")
            Button("Continue") {
                gameDirectoryPath = dir
                complete()
            }
            .keyboardShortcut(.defaultAction)
        case .none:
            EmptyView()
        }
    }

    private func openTerminal() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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

    private func statusRow(spinning: Bool, text: String) -> some View {
        HStack {
            if spinning { ProgressView().controlSize(.small) }
            Text(text)
        }
    }


    private var innoExtractMissingView: some View {
        missingHomebrewToolView(
            toolName: "innoextract",
            reason: "it's needed to unpack the GOG installer without running it",
            formula: "innoextract"
        )
    }

    private func missingHomebrewToolView(toolName: String, reason: String, formula: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(toolName) isn't installed — \(reason).", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            if Backend.brewPath != nil {
                Text("Run this in Terminal, then come back:").font(.caption).foregroundStyle(.secondary)
                Text("brew install \(formula)")
                    .font(.system(.callout, design: .monospaced))
                    .padding(6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            } else {
                Text("Homebrew isn't installed either. Install it from brew.sh first, then run: brew install \(formula)")
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

    private var backButton: some View { backButton(to: .chooseSource) }

    private func backButton(to target: WizardScreen) -> some View {
        Button {
            screen = target
        } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func complete() {
        wizardCompleted = true
        dismissWindow(id: "onboarding-wizard")
    }

    private func cancel() {
        dismissWindow(id: "onboarding-wizard")
    }
}
