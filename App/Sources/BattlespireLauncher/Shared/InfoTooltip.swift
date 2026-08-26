import SwiftUI

/// A small "?" icon that shows `text` (and an optional outbound link) in a
/// floating bubble a short moment after hover starts. SwiftUI's built-in
/// `.help()` rides the system tooltip timer (~1.5s, not configurable), so
/// this hand-rolls the delay via `onHover` + `popover` instead.
/// `accessibilityHint` covers VoiceOver independently of the visual bubble.
struct InfoTooltip: View {
    let text: String
    var linkURL: URL?
    var linkLabel: String = "Learn more"
    var hoverDelay: Double = 0.25
    var hideDelay: Double = 0.2

    @State private var isHoveringIcon = false
    @State private var isHoveringBubble = false
    @State private var showBubble = false

    private var isHoveringEither: Bool { isHoveringIcon || isHoveringBubble }

    var body: some View {
        Image(systemName: "questionmark.circle")
            .foregroundStyle(.secondary)
            .onHover { hovering in
                isHoveringIcon = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay) {
                        if isHoveringEither { showBubble = true }
                    }
                } else {
                    scheduleHideIfIdle()
                }
            }
            .popover(isPresented: $showBubble, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if let linkURL {
                        Link(linkLabel, destination: linkURL)
                            .font(.callout)
                    }
                }
                .frame(width: 240, alignment: .leading)
                .padding(10)
                // The popover is a separate view hierarchy from the icon, so
                // moving the cursor from the icon toward this content briefly
                // hovers neither -- without tracking hover here too (and a
                // short grace delay before hiding), that gap closes the
                // bubble before the cursor ever reaches a "Learn more" link.
                .onHover { hovering in
                    isHoveringBubble = hovering
                    if !hovering { scheduleHideIfIdle() }
                }
            }
            .accessibilityLabel("More info")
            .accessibilityHint(text)
    }

    private func scheduleHideIfIdle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
            if !isHoveringEither { showBubble = false }
        }
    }
}
