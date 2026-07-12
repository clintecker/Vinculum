#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics
import VinculumLayout

/// The CoreText implementation of layout's `MathTextMeasurer` seam: measures a
/// glyph run in the bundled math font (or the monospace fallback for
/// unsupported source), returning typographic bounds plus the ink extents that
/// drive accent placement. This is the only place layout touches CoreText.
enum CoreTextMeasurer {

    static func make() -> MathTextMeasurer {
        { text, size, mono in
            let ctFont: CTFont
            if mono {
                ctFont = PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular) as CTFont
            } else if let mathFont = MathFont.ctFont(size: size) {
                ctFont = mathFont
            } else {
                ctFont = PlatformFont.systemFont(ofSize: size) as CTFont
            }
            let attributed = NSAttributedString(string: text, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: ctFont])
            let line = CTLineCreateWithAttributedString(attributed)
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            let ink = CTLineGetImageBounds(line, nil)
            return GlyphMetrics(width: width, ascent: ascent, descent: descent,
                                inkAscent: min(ascent, max(0, ink.maxY)), inkDescent: ink.minY)
        }
    }
}
#endif
