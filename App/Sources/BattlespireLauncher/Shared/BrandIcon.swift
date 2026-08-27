import SwiftUI

/// Loads a bundled icon/logo file by name (see assets/icons/ATTRIBUTION.md
/// for source/license of each), falling back to an SF Symbol if the
/// resource fails to load for any reason -- callers always get *something*
/// rather than a blank icon.
enum BrandIcon {
    static func image(fileName: String, systemImageFallback: String) -> Image {
        guard let url = BundledResource.url(named: fileName),
              let nsImage = NSImage(contentsOf: url) else {
            return Image(systemName: systemImageFallback)
        }
        return Image(nsImage: nsImage)
    }
}
