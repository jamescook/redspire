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

    @State private var isHovering = false
    @State private var showBubble = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .foregroundStyle(.secondary)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay) {
                        if isHovering { showBubble = true }
                    }
                } else {
                    showBubble = false
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
            }
            .accessibilityLabel("More info")
            .accessibilityHint(text)
    }
}
