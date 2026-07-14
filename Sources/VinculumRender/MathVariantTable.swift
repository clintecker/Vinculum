#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics
import VinculumLayout

/// The bundled font's `MathVariants` data (size-variant ladders + glyph
/// assemblies), parsed once by the fixture-tested `MathTableParser` and
/// served to layout through the delimiter provider seams. Stretchy
/// delimiters try a purpose-drawn size variant first, then an assembly of
/// parts (Phase 5), and only then fall back to continuous scaling.
enum MathVariantTable {

    /// Parsed once; nil when the font/table is unavailable (layout scales).
    private static let data: MathVariantsData? = {
        guard let cgFont = MathFont.cgFont,
              let table = cgFont.table(for: 0x4D41_5448 /* 'MATH' */) else { return nil }
        return MathTableParser.variants(from: table as Data,
                                        unitsPerEm: Int(cgFont.unitsPerEm))
    }()

    private static func construction(for baseGlyph: String, size: CGFloat)
        -> (MathVariantsData.Construction, CTFont)? {
        guard let data, baseGlyph.unicodeScalars.count == 1,
              let ctFont = MathFont.ctFont(size: size) else { return nil }
        var utf16 = Array(baseGlyph.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &utf16, &glyphs, utf16.count),
              let baseID = glyphs.first, baseID != 0,
              let con = data.vertical[UInt16(baseID)] else { return nil }
        return (con, ctFont)
    }

    /// The smallest vertical size variant of `baseGlyph` at point `size`
    /// whose height reaches `minHeight`, or nil.
    static func shape(for baseGlyph: String, minHeight: CGFloat, size: CGFloat) -> DelimiterShape? {
        guard let (con, ctFont) = construction(for: baseGlyph, size: size) else { return nil }
        for v in con.variants where v.advance * size >= minHeight {
            var glyph = CGGlyph(v.glyphID)
            var rect = CGRect.zero, adv = CGSize.zero
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyph, &rect, 1)
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &adv, 1)
            let width = adv.width > 0 ? adv.width : rect.maxX
            let metrics = GlyphMetrics(width: width,
                                       ascent: max(0, rect.maxY), descent: max(0, -rect.minY),
                                       inkAscent: max(0, rect.maxY), inkDescent: rect.minY)
            guard metrics.ascent + metrics.descent > 0, width > 0 else { return nil }
            return DelimiterShape(glyphID: v.glyphID, metrics: metrics)
        }
        return nil
    }

    /// An assembled column of font parts reaching `minHeight`, or nil when
    /// the font provides no assembly for this glyph. Part glyphs in math
    /// fonts put their ink exactly on [0, fullAdvance] above the baseline,
    /// so draw offsets are the solved offsets directly.
    static func assembly(for baseGlyph: String, minHeight: CGFloat, size: CGFloat) -> DelimiterAssembly? {
        guard let data, let (con, ctFont) = construction(for: baseGlyph, size: size),
              let asm = con.assembly,
              let solved = MathAssemblySolver.solve(asm, minOverlap: data.minConnectorOverlap,
                                                    target: minHeight / size) else { return nil }
        var width: CGFloat = 0
        for p in solved.placements {
            var glyph = CGGlyph(p.glyphID)
            var adv = CGSize.zero
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &adv, 1)
            width = max(width, adv.width)
        }
        guard width > 0 else { return nil }
        let placements = solved.placements.map {
            MathAssemblySolver.Placement(glyphID: $0.glyphID, offset: $0.offset * size)
        }
        return DelimiterAssembly(placements: placements, width: width,
                                 height: solved.total * size)
    }
}

/// The injected `MathDelimiterProvider` backed by `MathVariantTable`.
public enum CoreTextDelimiterProvider {
    public static func make() -> MathDelimiterProvider {
        { glyph, minHeight, size in MathVariantTable.shape(for: glyph, minHeight: minHeight, size: size) }
    }

    /// The assembly companion: font parts for heights beyond the largest
    /// size variant.
    public static func makeAssembly() -> MathDelimiterAssemblyProvider {
        { glyph, minHeight, size in MathVariantTable.assembly(for: glyph, minHeight: minHeight, size: size) }
    }
}
#endif
