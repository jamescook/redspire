import SwiftUI

/// Shown when a shelled-out CLI tool (innoextract, steamcmd, dosbox-staging)
/// isn't installed -- points at the exact `brew install` command rather than
/// making the user go figure out what to run. Game-agnostic.
struct MissingHomebrewToolView: View {
    let toolName: String
    let reason: String
    let formula: String

    var body: some View {
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
}
