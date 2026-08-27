import SwiftUI
import UniformTypeIdentifiers

enum RedguardWizardScreen: Hashable {
    case chooseSource
    case steamMethodChoice
    case steamViaApp
    case steamViaCommand
    case steamViaAutomatic
    case gogGuide
    case discImage
}

/// Redguard's own setup wizard, mirroring OnboardingWizard's shape and
/// visual style for consistency. Steam support (this file's Steam screens)
/// is UNVERIFIED -- no Steam copy of this game was purchased to test
/// against, unlike GOG/disc where real testing caught real bugs. AppID
/// 1812410 and the installRoot/Redguard/ shape are confirmed via public
/// anonymous steamcmd metadata (no purchase needed for that), but the
/// actual depot contents (does it need the same DIG.INI/GLIDE2X.OVL
/// fixups GOG's package didn't?) are not.
struct RedguardOnboardingWizard: View {
    @AppStorage("redguardGameDirectoryPath") private var gameDirectoryPath = ""
    @AppStorage("redguardCdImagePath") private var cdImagePath = ""
    @AppStorage("redguardWizardCompleted") private var wizardCompleted = false
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var screen: RedguardWizardScreen = .chooseSource
    @State private var manualErrorMessage: String?
    @State private var playDiscPath = ""
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
    // Bumped when MissingHomebrewToolView finishes installing a tool -- a
    // @State change here forces this struct's body (and so whichever
    // `if <tool>.isInstalled` branch below) to re-evaluate.
    @State private var toolRefreshToken = UUID()
    private let credentialStore: CredentialStore = KeychainCredentialStore()
    @StateObject private var gogInstaller = RedguardGogInstaller()
    @StateObject private var discInstaller = RedguardDiscImageInstaller()
    @StateObject private var steamCMDSession = SteamCMDSession(
        appID: RedguardSteamCMDInstaller.appID,
        exeLabel: "REDGUARD.EXE",
        findInstalledGameDir: { RedguardSteamCMDInstaller.findInstalledGameDir(root: $0) }
    )

    private var steamCMDCommand: String {
        RedguardSteamCMDInstaller.command(
            username: steamUsername,
            destDir: RedguardSteamCMDInstaller.installDestination.path
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch screen {
            case .chooseSource: chooseSourceView
            case .steamMethodChoice: steamMethodChoiceView
            case .steamViaApp: steamViaAppView
            case .steamViaCommand: steamViaCommandView
            case .steamViaAutomatic: steamViaAutomaticView
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
            selectedSteamMethod = nil
            steamRedetectAttempted = false
            gogInstaller.reset()
            discInstaller.reset()
            steamCMDSession.reset()
            detectedSteamPath = RedguardSteamDetector.findGameDirectory()
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
                Text("Welcome to Redguard Launcher")
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
                icon: BrandIcon.image(fileName: "steam-logo.svg", systemImageFallback: "gamecontroller")
            ) { manualErrorMessage = nil; steamCMDSession.reset(); screen = .steamMethodChoice }

            sourceCard(
                title: "GOG",
                subtitle: "I bought it on GOG.com",
                icon: BrandIcon.image(fileName: "gog-logo.png", systemImageFallback: "arrow.down.circle")
            ) { manualErrorMessage = nil; gogInstaller.reset(); screen = .gogGuide }

            sourceCard(
                title: "I have the original disc(s)",
                subtitle: "Extract from a ripped install-disc image (.iso)",
                icon: Image(systemName: "opticaldiscdrive")
            ) { manualErrorMessage = nil; playDiscPath = ""; discInstaller.reset(); screen = .discImage }

            sourceCard(
                title: "I already have it installed",
                subtitle: "Point me at an existing Redguard install folder",
                icon: Image(systemName: "folder")
            ) { chooseExistingFolder() }

            if let manualErrorMessage {
                Label(manualErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceCard(title: String, subtitle: String, icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
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
            manualErrorMessage = "Couldn't find Redguard/REDGUARD.EXE in that folder -- pick the folder "
                + "that has a Redguard subfolder directly inside it."
            return
        }

        gameDirectoryPath = url.path
        complete()
    }

    // MARK: - Steam: method choice

    private var steamMethodChoiceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton
            Text("How do you want to install it?").font(.title2).bold()
            Label("Redguard doesn't appear to be installed via Steam yet.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(SteamInstallMethod.allCases) { method in
                    methodChoiceCard(method)
                }
            }

            if let selected = selectedSteamMethod {
                Button("Continue") {
                    switch selected {
                    case .steamApp: screen = .steamViaApp
                    case .runCommandMyself: screen = .steamViaCommand
                    case .letAppDoIt: screen = .steamViaAutomatic
                    }
                }
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
            Text("Install it normally through the Steam app -- Redguard's AppID is 1812410.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Steam Store Page") {
                NSWorkspace.shared.open(URL(string: "https://store.steampowered.com/app/1812410")!)
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
                MissingHomebrewToolView(
                    toolName: "steamcmd",
                    reason: "it can download the game files directly, without installing the full Steam client",
                    formula: "steamcmd",
                    onInstalled: { toolRefreshToken = UUID() }
                )
            } else {
                Text(
                    "Enter your Steam username, then copy this command and run it in Terminal -- it'll prompt "
                        + "you for your password and Steam Guard code there."
                )
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Steam username", text: $steamUsername)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .frame(maxWidth: 240)
                Text(steamCMDCommand)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
                    .textSelection(.enabled)
                HStack {
                    Button(commandCopied ? "Copied!" : "Copy Command") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(steamCMDCommand, forType: .string)
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
                MissingHomebrewToolView(
                    toolName: "steamcmd",
                    reason: "it can download the game files directly, without installing the full Steam client",
                    formula: "steamcmd",
                    onInstalled: { toolRefreshToken = UUID() }
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
                        destDir: RedguardSteamCMDInstaller.installDestination.path,
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
            text: "steamcmd is Valve's official command-line tool for downloading Steam games without the full Steam "
                + "app — handy for headless/automated installs.",
            linkURL: URL(string: "https://developer.valvesoftware.com/wiki/SteamCMD")!
        )
    }

    private var manualDetectFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("I've Installed It — Detect Again") {
                steamRedetectAttempted = true
                if let found = RedguardSteamDetector.findGameDirectory()
                    ?? RedguardSteamCMDInstaller.findInstalledGameDir() {
                    gameDirectoryPath = found
                    complete()
                }
            }
            .keyboardShortcut(.defaultAction)

            if steamRedetectAttempted
                && RedguardSteamDetector.findGameDirectory() == nil
                && RedguardSteamCMDInstaller.findInstalledGameDir() == nil {
                Label(
                    "Still not found. Make sure the install finished, then try again.",
                    systemImage: "exclamationmark.triangle"
                )
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
            installerOptionCard(
                icon: "checkmark.circle.fill",
                color: .green,
                text: "Downloaded successfully via steamcmd."
            )
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
                        text: "The \"offline backup installer\" (100s of MB, named setup_*.exe) — this is the one "
                            + "you need."
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
                    let urlString = "https://www.gog.com/en/game/the_elder_scrolls_adventures_redguard"
                    NSWorkspace.shared.open(URL(string: urlString)!)
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
                formula: "innoextract",
                onInstalled: { toolRefreshToken = UUID() }
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
                case .needsGlideDriver:
                    gogGlideDriverPrompt
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
                Text(
                    "Point this at a ripped copy of Disc 1 (the Install Disc) as a .iso file. If you haven't "
                        + "ripped it yet, ripping tools like bchunk can pull one off the physical disc."
                )
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
                reason: "the retail disc's installer is an InstallShield package that needs it to unpack without "
                    + "running Windows",
                formula: "unshield",
                onInstalled: { toolRefreshToken = UUID() }
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
            missingGlideDriverPrompt(
                message: "Everything else is ready, but this game also needs a file called GLIDE2X.OVL that the "
                    + "retail disc doesn't include (a licensing thing, not a bug on our end).",
                secondaryText: "If you also own this game on GOG, open that install's DOSBOX folder and pick "
                    + "glide2x_emu.ovl there. Otherwise, DOSBox-X's own guide explains where to find an official "
                    + "copy."
            ) {
                Button("Choose File…") { browseForGlideDriver(gameDir: gameDir) }
                Button("Open DOSBox-X's Guide") {
                    let urlString = "https://dosbox-x.com/wiki/Guide:Setting-up-3dfx-Voodoo-in-DOSBox%E2%80%90X"
                    NSWorkspace.shared.open(URL(string: urlString)!)
                }
            }
        }
    }

    @ViewBuilder
    private var gogGlideDriverPrompt: some View {
        if case .needsGlideDriver(let gameDir) = gogInstaller.stage {
            missingGlideDriverPrompt(
                message: "Everything else is ready, but this game also needs a file called GLIDE2X.OVL that "
                    + "couldn't be copied into place from this installer.",
                secondaryText: "This installer normally includes it in its own DOSBOX folder as glide2x_emu.ovl -- "
                    + "if you still have the extracted files, point at that copy directly."
            ) {
                Button("Choose File…") { browseForGogGlideDriver(gameDir: gameDir) }
                Button("Try Again") { browseForInstaller() }
            }
        }
    }

    private func missingGlideDriverPrompt(
        message: String, secondaryText: String, @ViewBuilder buttons: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            installerOptionCard(icon: "exclamationmark.triangle.fill", color: .orange, text: message)
            Text(secondaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack { buttons() }
        }
    }

    private var playDiscPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                "This game also plays its videos and music from its second disc while you're playing. Add that "
                    + "now so everything works, or add it later from the main screen."
            )
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

    private func browseForGogGlideDriver(gameDir: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select glide2x_emu.ovl (or another legitimate GLIDE2X.OVL)"
        if panel.runModal() == .OK, let url = panel.url {
            gogInstaller.supplyGlideDriver(fromPath: url.path, gameDir: gameDir)
        }
    }

    private var backButton: some View { backButton(to: .chooseSource) }

    private func backButton(to target: RedguardWizardScreen) -> some View {
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
        dismissWindow(id: "redguard-onboarding-wizard")
    }

    private func cancel() {
        dismissWindow(id: "redguard-onboarding-wizard")
    }
}
