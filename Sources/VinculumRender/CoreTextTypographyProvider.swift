#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import VinculumLayout

/// The injected `MathGlyphTypographyProvider` backed by the bundled font's
/// parsed `MathGlyphInfo` (Phase 3): resolves the rendered glyph string to a
/// glyph ID via CoreText, then scales the em-relative table values to the
/// queried point size. Returns nil for glyphs the table doesn't cover, so
/// layout falls back to neutral defaults.
public enum CoreTextTypographyProvider {

    public static func make() -> MathGlyphTypographyProvider {
        { glyph, size in
            guard let info = MathFont.glyphInfo,
                  glyph.unicodeScalars.count == 1,
                  let ctFont = MathFont.ctFont(size: size) else { return nil }
            var utf16 = Array(glyph.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
            guard CTFontGetGlyphsForCharacters(ctFont, &utf16, &glyphs, utf16.count),
                  let id = glyphs.first, id != 0 else { return nil }
            let gid = UInt16(id)

            let italic = info.italicsCorrection[gid]
            let accent = info.topAccentAttachment[gid]
            let kerns = info.kerns[gid]
            guard italic != nil || accent != nil || kerns != nil else { return nil }
            return GlyphTypography(
                italicCorrection: (italic ?? 0) * size,
                topAccentAttachment: accent.map { $0 * size },
                kernTopRight: kerns?.topRight?.scaled(by: size),
                kernBottomRight: kerns?.bottomRight?.scaled(by: size))
        }
    }
}
#endif
