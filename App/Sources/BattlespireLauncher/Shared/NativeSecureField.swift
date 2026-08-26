import SwiftUI
import AppKit

/// Wraps a real AppKit NSSecureTextField instead of SwiftUI's SecureField.
/// SwiftUI's SecureField doesn't reliably anchor the system Password AutoFill /
/// Credential Provider panel (1Password, iCloud Keychain, etc.) on macOS --
/// a genuine NSSecureTextField does, since that's what the system's AutoFill
/// machinery actually targets (confirmed: works in Finder's native
/// "Connect to Server" password field, glitches in SwiftUI's SecureField).
struct NativeSecureField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        if #available(macOS 11.0, *) {
            field.contentType = .password
        }
        return field
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        // SwiftUI calls this on every re-render, for any reason, anywhere in
        // the view tree. While this field is focused/being edited -- which
        // includes an AutoFill provider injecting text into it -- forcing
        // nsView.stringValue back to our (possibly stale) @State clobbers
        // whatever's actively being typed/injected. Only sync in when
        // nothing is editing it.
        guard nsView.currentEditor() == nil else { return }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSecureTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
