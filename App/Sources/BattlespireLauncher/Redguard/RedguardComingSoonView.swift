import SwiftUI

/// Shown when Redguard mode is selected before real support exists (lands in
/// battlespire-macos-ao9.2+). Deliberately not a blank screen -- an empty or
/// broken-looking view here would leave the user wondering if they hit a bug.
struct RedguardComingSoonView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: GameMode.redguard.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Redguard")
                .font(.title2).bold()
            Text("Support for *The Elder Scrolls Adventures: Redguard* is on\nthe way, but isn't ready yet. Switch back to Battlespire\nfor now.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 480)
    }
}
