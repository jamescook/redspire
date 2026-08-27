import SwiftUI

/// Top-level shell: owns the game-mode picker and routes to each mode's own
/// content view below it. Each mode's content view owns its own settings
/// keys/session entirely -- RootView only tracks which one is showing and
/// whether a session is running anywhere, to lock the picker mid-game.
struct RootView: View {
    @State private var mode: GameMode
    private let modeStore: GameModeStore

    @StateObject private var battlespireSession = GameSession()
    @StateObject private var redguardSession = RedguardGameSession()

    init(modeStore: GameModeStore = UserDefaultsGameModeStore()) {
        self.modeStore = modeStore
        _mode = State(initialValue: modeStore.loadMode())
    }

    private var isSessionRunning: Bool {
        battlespireSession.isRunning || redguardSession.isRunning
    }

    /// Pure: whether the mode picker should accept input right now.
    static func isPickerEnabled(isSessionRunning: Bool) -> Bool {
        !isSessionRunning
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .battlespire:
            ContentView(session: battlespireSession)
        case .redguard:
            RedguardContentView(session: redguardSession)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            Picker("Game", selection: $mode) {
                ForEach(GameMode.allCases) { m in
                    Label {
                        Text(m.displayName)
                    } icon: {
                        BrandIcon.image(fileName: m.iconFileName, systemImageFallback: m.systemImage)
                    }
                    .tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!Self.isPickerEnabled(isSessionRunning: isSessionRunning))
            .onChange(of: mode) { _, newMode in modeStore.save(mode: newMode) }

            if isSessionRunning {
                InfoTooltip(text: "Quit the running game before switching modes.")
            }
        }
        .padding([.horizontal, .top], 16)
        .padding(.bottom, 12)
    }
}
