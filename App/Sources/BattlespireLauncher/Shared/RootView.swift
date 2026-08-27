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

    @State private var showingResetConfirmation = false
    @State private var resetBlockedBySessionRunning = false

    init(modeStore: GameModeStore = UserDefaultsGameModeStore()) {
        self.modeStore = modeStore
        _mode = State(initialValue: modeStore.loadMode())
    }

    private var isSessionRunning: Bool {
        battlespireSession.isRunning || redguardSession.isRunning
    }

    /// Pure: whether the mode picker should accept input right now.
    nonisolated static func isPickerEnabled(isSessionRunning: Bool) -> Bool {
        !isSessionRunning
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            Divider()
            content
        }
        // Without this, switching tabs to a shorter mode leaves the window
        // at its previous (taller) size -- SwiftUI then centers this VStack
        // in the leftover space instead of anchoring it to the top, so the
        // heading visibly jumps up/down depending which tab you're on. This
        // pins content flush under the divider regardless of window height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: .requestResetToDefaults)) { _ in
            if isSessionRunning {
                resetBlockedBySessionRunning = true
            } else {
                showingResetConfirmation = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestDirectLaunch)) { notification in
            guard let requestedMode = notification.object as? GameMode else { return }
            directLaunch(mode: requestedMode)
        }
        .alert("Reset to Defaults?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                AppDefaultsReset.reset()
                mode = .battlespire
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This clears both games' saved folders, settings, and any remembered Steam password. It does "
                    + "not delete any installed game files."
            )
        }
        .alert("Quit the running game first", isPresented: $resetBlockedBySessionRunning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Can't reset settings while a game is running.")
        }
    }

    /// Entry point for a Desktop shortcut reopening the app (see
    /// DesktopShortcutCreator/DirectLaunchURL): switches to that game's tab
    /// and plays it with its own persisted settings, exactly as its Play
    /// button would, then hides this window so the DOSBox window (already
    /// launched by play()) is what the user actually sees.
    private func directLaunch(mode requestedMode: GameMode) {
        mode = requestedMode
        modeStore.save(mode: requestedMode)

        let settings = GameLaunchSettings.load(for: requestedMode)
        let session: PlayableGameSession = requestedMode == .battlespire ? battlespireSession : redguardSession
        session.play(
            gameDir: settings.gameDirectoryPath, cdImagePathOverride: settings.cdImagePath,
            backend: settings.backend, fullscreen: settings.fullscreen, memsizeMB: settings.memsizeMB
        )

        // Only hide the window once the session actually started -- if
        // play() failed (e.g. this game's folder was never configured),
        // the window must stay visible so the user can see why, instead of
        // silently vanishing with no explanation. The slight delay is
        // load-bearing, confirmed live: opening a `redspire://` URL while
        // the app was already running in the background makes Launch
        // Services activate/foreground it as part of delivering that URL,
        // and that activation lands microseconds AFTER this notification
        // handler runs, silently un-minimizing a window we'd just hidden.
        // Miniaturizing on the next runloop turn instead lets our call go
        // last.
        if session.isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.windows.first(where: { $0.title == RedspireApp.mainWindowTitle })?.miniaturize(nil)
            }
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
                ForEach(GameMode.allCases) { candidate in
                    Text(candidate.displayName).tag(candidate)
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
