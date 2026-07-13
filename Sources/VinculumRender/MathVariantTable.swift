#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics
import VinculumLayout

/// Parses the bundled math font's OpenType **MATH** table (`MathVariants` →
/// vertical glyph construction) so stretchy delimiters use the font's discrete
/// size-variant glyphs — purpose-drawn taller cuts with constant stroke weight
/// — instead of continuous point-scaling (which fattens strokes). Everything is
/// bounds-checked; any malformation yields an empty map and layout falls back
/// to scaling. Stage 1: size variants only (no extensible assembly).
enum MathVariantTable {

    // baseGlyphID → ascending [(variantGlyphID, advance in design units)].
    nonisolated(unsafe) private static var cache: [UInt16: [(glyph: UInt16, advance: UInt16)]]?
    private static let lock = NSLock()

    /// The smallest vertical size variant of `baseGlyph` at point `size` whose
    /// height reaches `minHeight`, or nil (no tall-enough cut → caller scales).
    // Only the delimiters whose MATH-table variants are verified to render
    // correctly. The parser mis-maps some others (e.g. ⟨ ⟩ ‖), which safely
    // fall through to continuous scaling until the parse is hardened.
    private static let verified: Set<String> = ["(", ")", "[", "]", "{", "}"]

    static func shape(for baseGlyph: String, minHeight: CGFloat, size: CGFloat) -> DelimiterShape? {
        guard verified.contains(baseGlyph), baseGlyph.unicodeScalars.count == 1,
              let ctFont = MathFont.ctFont(size: size) else { return nil }
        var utf16 = Array(baseGlyph.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &utf16, &glyphs, utf16.count),
              let baseID = glyphs.first, baseID != 0 else { return nil }
        let variants = table()
        guard let list = variants[UInt16(baseID)] else { return nil }
        let upm = CGFloat(CTFontGetUnitsPerEm(ctFont))
        guard upm > 0 else { return nil }

        for v in list where CGFloat(v.advance) * size / upm >= minHeight {
            // The variant is a normal glyph drawn with horizontal orientation
            // (just taller), so measure it that way.
            var glyph = CGGlyph(v.glyph)
            var rect = CGRect.zero, adv = CGSize.zero
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyph, &rect, 1)
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &adv, 1)
            let width = adv.width > 0 ? adv.width : rect.maxX
            let metrics = GlyphMetrics(width: width,
                                       ascent: max(0, rect.maxY), descent: max(0, -rect.minY),
                                       inkAscent: max(0, rect.maxY), inkDescent: rect.minY)
            guard metrics.ascent + metrics.descent > 0, width > 0 else { return nil }
            return DelimiterShape(glyphID: v.glyph, metrics: metrics)
        }
        return nil
    }

    private static func table() -> [UInt16: [(glyph: UInt16, advance: UInt16)]] {
        lock.lock(); defer { lock.unlock() }
        if let c = cache { return c }
        let parsed = parse()
        cache = parsed
        return parsed
    }

    // MARK: - Binary parse (big-endian)

    private static func parse() -> [UInt16: [(glyph: UInt16, advance: UInt16)]] {
        guard let cgFont = MathFont.cgFont,
              let cfData = cgFont.table(for: 0x4D415448 /* 'MATH' */) else { return [:] }
        let b = [UInt8](cfData as Data)
        func u16(_ o: Int) -> Int? { (o >= 0 && o + 1 < b.count) ? Int(b[o]) << 8 | Int(b[o + 1]) : nil }

        // MATH header: version(4) · mathConstants@4 · mathGlyphInfo@6 · mathVariants@8.
        guard let mvOff = u16(8), mvOff > 0 else { return [:] }
        let mv = mvOff
        guard let vertCovOff = u16(mv + 2), let vertCount = u16(mv + 6) else { return [:] }
        let cov = mv + vertCovOff

        // Coverage: glyphID → coverage index.
        var glyphForIndex: [Int: UInt16] = [:]
        guard let covFormat = u16(cov) else { return [:] }
        if covFormat == 1 {
            guard let n = u16(cov + 2) else { return [:] }
            for j in 0..<n { if let g = u16(cov + 4 + 2 * j) { glyphForIndex[j] = UInt16(g) } }
        } else if covFormat == 2 {
            guard let ranges = u16(cov + 2) else { return [:] }
            for r in 0..<ranges {
                let base = cov + 4 + 6 * r
                guard let start = u16(base), let end = u16(base + 2), let startIdx = u16(base + 4) else { continue }
                for g in start...max(start, end) { glyphForIndex[startIdx + (g - start)] = UInt16(g) }
            }
        } else { return [:] }

        // For each coverage index, read its MathGlyphConstruction's variant list.
        var out: [UInt16: [(glyph: UInt16, advance: UInt16)]] = [:]
        for i in 0..<vertCount {
            guard let glyphID = glyphForIndex[i],
                  let constrOff = u16(mv + 10 + 2 * i) else { continue }
            let gc = mv + constrOff
            guard let variantCount = u16(gc + 2) else { continue }
            var variants: [(glyph: UInt16, advance: UInt16)] = []
            for k in 0..<variantCount {
                let rec = gc + 4 + 4 * k
                guard let vg = u16(rec), let adv = u16(rec + 2) else { break }
                variants.append((UInt16(vg), UInt16(adv)))
            }
            if !variants.isEmpty { out[glyphID] = variants }
        }
        return out
    }
}

/// The injected `MathDelimiterProvider` backed by `MathVariantTable`.
public enum CoreTextDelimiterProvider {
    public static func make() -> MathDelimiterProvider {
        { glyph, minHeight, size in MathVariantTable.shape(for: glyph, minHeight: minHeight, size: size) }
    }
}
#endif
