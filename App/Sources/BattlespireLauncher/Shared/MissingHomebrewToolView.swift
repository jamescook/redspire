import SwiftUI

/// Shown when a shelled-out CLI tool (innoextract, steamcmd, unshield,
/// dosbox-staging) isn't installed -- self-heals via the same
/// BrewInstaller-backed "Install via Homebrew" button ContentView
/// established for dosbox-staging, rather than just printing a command for
/// the user to go run themselves. Game-agnostic.
///
/// `onInstalled` fires once the install succeeds -- callers use it to bump
/// a @State token on the containing view, forcing that view's body (and so
/// whatever `if <tool>.isInstalled` branch is wrapping this view) to
/// re-evaluate, since a @State change owned by this view alone can't
/// retrigger a branch decision made in the parent's body.
struct MissingHomebrewToolView: View {
    let toolName: String
    let reason: String
    let formula: String
    var onInstalled: () -> Void = {}

    @State private var installer = BrewInstaller()
    @State private var isInstalling = false
    @State private var installLog = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(toolName) isn't installed — \(reason).", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            if Backend.brewPath != nil {
                Button(isInstalling ? "Installing…" : "Install via Homebrew") { install() }
                    .disabled(isInstalling)
                if !installLog.isEmpty {
                    LogScrollView(text: installLog, height: 80)
                }
            } else {
                Text(
                    "Homebrew isn't installed either. Install it from brew.sh first, then run: "
                        + "brew install \(formula)"
                )
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open brew.sh") {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                }
            }
        }
    }

    private func install() {
        isInstalling = true
        installLog = ""
        installer.install(formula: formula, onOutput: { line in
            Task { @MainActor in installLog += line }
        }, onComplete: { success in
            Task { @MainActor in
                isInstalling = false
                installLog += success ? "\nDone.\n" : "\nInstall failed — see output above.\n"
                if success { onInstalled() }
            }
        })
    }
}
