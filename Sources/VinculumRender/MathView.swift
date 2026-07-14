#if canImport(SwiftUI) && (canImport(AppKit) || canImport(UIKit))
import SwiftUI
import VinculumLayout

/// First-party SwiftUI math view:
///
/// ```swift
/// MathView(#"e^{i\pi} + 1 = 0"#)
///     .mathFont(.termes)
/// ```
///
/// Renders through `MathImageRenderer`'s cache and sizes itself to the
/// equation. Unsupported LaTeX renders nothing (check with
/// `MathParser.isFullySupported` if you need a fallback), keeping the
/// never-half-broken contract.
public struct MathView: View {
    private let latex: String
    private var display: Bool = true
    private var font: MathFont = .latinModern
    private var theme: MathTheme = .light
    private var baseSize: CGFloat = 17

    public init(_ latex: String) {
        self.latex = latex
    }

    public var body: some View {
        if let image = renderedImage() {
            #if canImport(AppKit)
            Image(nsImage: image).renderingMode(image.isTemplate ? .template : .original)
            #else
            Image(uiImage: image)
            #endif
        }
    }

    private func renderedImage() -> PlatformImage? {
        guard let attributed = MathImageRenderer.attachmentString(
            latex: latex, display: display, mathTheme: theme, baseSize: baseSize, font: font)
        else { return nil }
        var image: PlatformImage?
        attributed.enumerateAttribute(
            .attachment, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let a = value as? NSTextAttachment, let i = a.image { image = i }
        }
        return image
    }

    // MARK: - Modifiers

    /// Inline (text) style instead of display style.
    public func inlineStyle(_ inline: Bool = true) -> MathView {
        var copy = self; copy.display = !inline; return copy
    }
    public func mathFont(_ font: MathFont) -> MathView {
        var copy = self; copy.font = font; return copy
    }
    public func mathTheme(_ theme: MathTheme) -> MathView {
        var copy = self; copy.theme = theme; return copy
    }
    public func mathSize(_ size: CGFloat) -> MathView {
        var copy = self; copy.baseSize = size; return copy
    }
}
#endif
