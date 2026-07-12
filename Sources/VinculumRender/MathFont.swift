#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics

/// The bundled OpenType math font (Latin Modern Math) plus the metrics from
/// its MATH table. This is what gives Vinculum genuine LaTeX quality — the
/// Computer-Modern glyph shapes AND the typesetting constants (axis height,
/// rule thickness, script scales, shifts) that a math font is required to
/// carry. Falls back to the system font if the resource can't be loaded, so
/// rendering degrades rather than fails.
enum MathFont {

    /// The loaded CGFont for the bundled math font, or nil if unavailable.
    static let cgFont: CGFont? = {
        guard let url = Bundle.module.url(forResource: "latinmodern-math", withExtension: "otf"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return nil }
        return font
    }()

    static var isAvailable: Bool { cgFont != nil }

    /// A CTFont for the math font at `size`, or nil (caller falls back).
    static func ctFont(size: CGFloat) -> CTFont? {
        guard let cgFont else { return nil }
        return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
    }
}
// The MATH-table constants moved to VinculumLayout's `MathConstants` (they're
// pure numbers the platform-free layout stage needs).
#endif
