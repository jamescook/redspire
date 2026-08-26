import SwiftUI

/// A monospaced, auto-tailing log view -- scrolls to the bottom whenever
/// `text` grows, like `tail -f`, so the reader never has to scroll manually.
struct LogScrollView: View {
    let text: String
    var height: CGFloat = 140

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("logEnd")
            }
            .frame(height: height)
            .background(Color.black.opacity(0.05))
            .onChange(of: text) {
                proxy.scrollTo("logEnd", anchor: .bottom)
            }
        }
    }
}
