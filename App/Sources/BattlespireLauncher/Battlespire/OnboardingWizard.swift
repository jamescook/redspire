import SwiftUI
import UniformTypeIdentifiers

enum WizardScreen: Hashable {
    case chooseSource
    case steamMethodChoice
    case steamViaApp
    case steamViaCommand
    case steamViaAutomatic
    case gogGuide
    case manualIssues
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
    @AppStorage("cdImagePath") private var cdImagePath = ""
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
    @State private var manualGameDir = ""
    @State private var manualCDImageMissing = false
    @State private var manualIsOldVersion = false
    @State private var manualVersionString: String?
    @State private var manualExtracting = false
    @State private var manualErrorMessage: String?
    @State private var manualPatchApplySuccessMessage: String?
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
            case .manualIssues: manualIssuesView
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
            manualErrorMessage = nil
            manualPatchApplySuccessMessage = nil
            manualCDImageMissing = false
            manualIsOldVersion = false
            detectedSteamPath = SteamDetector.findGameDirectory()
            savedAccounts = credentialStore.listAccounts()
            gogInstaller.reset()
            steamCMDSession.reset()
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
            ) { manualErrorMessage = nil; steamCMDSession.reset(); screen = .steamMethodChoice }

            sourceCard(
                title: "GOG",
                subtitle: "I bought it on GOG.com",
                systemImage: "arrow.down.circle"
            ) { manualErrorMessage = nil; gogInstaller.reset(); screen = .gogGuide }

            sourceCard(
                title: "I already have it installed",
                subtitle: "Point me at an existing game folder, or a disc image if you haven't unpacked it",
                systemImage: "folder"
            ) { chooseExistingFolder() }

            if manualExtracting {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Reading disc image…")
                }
                .foregroundStyle(.secondary)
            }
            if let manualErrorMessage, screen == .chooseSource {
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
        manualErrorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select your game folder, or a disc image (.iso) if you haven't unpacked it anywhere"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            finishManualInstall(gameDir: url.path, cdImageOverride: nil)
        } else if url.pathExtension.lowercased() == "iso" {
            let isoPath = url.path
            manualExtracting = true
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let extracted = try DiscImageInstaller.extractGameFiles(fromISO: isoPath)
                    DispatchQueue.main.async {
                        manualExtracting = false
                        finishManualInstall(gameDir: extracted, cdImageOverride: isoPath)
                    }
                } catch {
                    DispatchQueue.main.async {
                        manualExtracting = false
                        manualErrorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            manualErrorMessage = "That's not a game folder or a disc image (.iso) -- pick one of those."
        }
    }

    private func finishManualInstall(gameDir: String, cdImageOverride: String?) {
        // Checks one level down too (e.g. a batspire/ subfolder), same as
        // the disc-image and patch-apply paths -- so picking the outer
        // folder someone unzipped/extracted to just works.
        guard let resolvedGameDir = DiscImageInstaller.findGameDir(atRoot: gameDir) else {
            manualErrorMessage = "Couldn't find GAME.EXE in that folder (checked one level down too) -- pick the folder that has it, or its parent."
            return
        }

        manualGameDir = resolvedGameDir
        gameDirectoryPath = resolvedGameDir
        if let cdImageOverride {
            cdImagePath = cdImageOverride
        }

        // A raw retail-disc layout can have MSS as a sibling of the
        // batspire/ folder rather than inside it, and no SPIRE.CFG at all
        // (the original installer generates it, and we never run that) --
        // same fix as the direct disc-image path, using the originally
        // picked folder as the place to look for a sibling MSS.
        try? DiscImageInstaller.fillInMissingSupportFiles(gameDir: resolvedGameDir, mountRoot: gameDir)

        recheckManualInstall()
        if manualCDImageMissing || manualIsOldVersion {
            screen = .manualIssues
        } else {
            complete()
        }
    }

    private func recheckManualInstall() {
        let exe = (manualGameDir as NSString).appendingPathComponent("GAME.EXE")
        manualCDImageMissing = cdImagePath.isEmpty && CDImageDetector.autoDetect(inGameDir: manualGameDir) == nil
        let version = GameVersion.detect(gameExePath: exe)
        manualVersionString = version
        manualIsOldVersion = !GameVersion.isV15(version)
    }

    private func chooseCDImageForManualInstall() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "iso"), UTType(filenameExtension: "ins"), UTType(filenameExtension: "cue")].compactMap { $0 }
        panel.prompt = "Select"
        panel.message = "Select the disc image (.iso/.ins/.cue)"
        if panel.runModal() == .OK, let url = panel.url {
            cdImagePath = url.path
            manualErrorMessage = nil
            recheckManualInstall()
        }
    }

    private func applyPatchForManualInstall() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = "Select"
        panel.message = "Select batpat15.zip (or .exe), or a folder you already extracted it to"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        manualPatchApplySuccessMessage = nil
        do {
            try PatchApplier.applyFromZipOrFolder(path: url.path, toGameDir: manualGameDir)
            recheckManualInstall()
            if manualIsOldVersion {
                manualErrorMessage = "Copied files from that, but it still doesn't look like v1.5 (detected: \(manualVersionString ?? "no version string found")). Make sure you picked the official v1.5 patch, not something else."
            } else {
                manualErrorMessage = nil
                let exe = (manualGameDir as NSString).appendingPathComponent("GAME.EXE")
                let verified = KnownGoodBuilds.isVerified(gameExePath: exe)
                manualPatchApplySuccessMessage = verified
                    ? "Update applied — matches a verified official v1.5 build."
                    : "Update applied — now running \(manualVersionString ?? "v1.5") (doesn't match our known-good checksum, but the version string looks right)."
            }
        } catch {
            manualErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Manual install: issues found

    private var manualIssuesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            backButton
            Text("A couple things to check").font(.title2).bold()

            if manualCDImageMissing {
                issueSection(
                    title: "Missing a disc file",
                    detail: "This copy is missing a file the game reads from while playing (music, some game data). If you have it separately -- for example your own disc rip -- add it here.",
                    actionLabel: "Choose Disc File…",
                    action: chooseCDImageForManualInstall
                )
            }

            if manualIsOldVersion {
                VStack(alignment: .leading, spacing: 8) {
                    issueSection(
                        title: "Older version detected" + (manualVersionString.map { " — \($0)" } ?? ""),
                        detail: "This looks like the original 1997 release, which has some known bugs (freezing, mouse issues) when run today. There's a free official update that fixes it. Once you've downloaded and unzipped it, point us at those files and we'll copy them in.",
                        actionLabel: "Apply Update…",
                        action: applyPatchForManualInstall
                    )
                    Button("Get the Update from Archive.org") {
                        NSWorkspace.shared.open(URL(string: "https://archive.org/details/batpat15")!)
                    }
                    .font(.caption)
                }
            }

            if let manualPatchApplySuccessMessage {
                Label(manualPatchApplySuccessMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let manualErrorMessage {
                Label(manualErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(manualCDImageMissing || manualIsOldVersion ? "Continue Anyway" : "Continue") {
                complete()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func issueSection(title: String, detail: String, actionLabel: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionLabel, action: action)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
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
                MissingHomebrewToolView(
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
                MissingHomebrewToolView(
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
        MissingHomebrewToolView(
            toolName: "innoextract",
            reason: "it's needed to unpack the GOG installer without running it",
            formula: "innoextract"
        )
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
