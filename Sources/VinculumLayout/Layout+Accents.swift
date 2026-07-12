import Foundation

extension MathLayoutEngine {

    /// Accents over a base (`\hat \vec \bar …`), stretchy variants, and the
    /// `\overline`/`\underline` rules. Point accents sit on the base's actual
    /// ink top so a hat hugs `x` instead of floating at the font ascent.
    func accentBox(_ base: MathNode, accent: MathAccent, size: CGFloat, display: Bool) -> MathBox {
        let baseBox = box(for: base, size: size, display: display)
        let ruleThickness = max(1, size * 0.045)
        let gap = size * 0.08

        // Drawn rules: \overline above, \underline below.
        if accent == .overline || accent == .underline {
            let over = accent == .overline
            let ascent = baseBox.ascent + (over ? gap + ruleThickness : 0)
            let descent = baseBox.descent + (over ? 0 : gap + ruleThickness)
            var elements = baseBox.elements
            let y = over ? baseBox.ascent + gap : -baseBox.descent - gap - ruleThickness
            elements.append(rule(x: 0, y: y, width: baseBox.width, height: ruleThickness))
            return MathBox(width: baseBox.width, ascent: ascent, descent: descent, elements: elements)
        }

        guard let rawGlyph = accent.glyph else { return baseBox }
        // Stretchy accents (\widehat/\widetilde) scale toward the base width;
        // point accents keep their natural size.
        let accentSize = accent.isStretchy
            ? min(size * 1.6, max(size * 0.7, baseBox.width * 0.9))
            : size * 0.9
        let glyph = Self.mathVariant(rawGlyph, italic: false, bold: false)
        let m = measure(glyph, accentSize, false)
        let clearance = size * 0.02
        // Baseline for the accent such that its ink bottom sits just above the
        // base's ink top.
        let accentBaselineY = baseBox.inkAscent + clearance - m.inkDescent
        let ascent = max(baseBox.ascent, accentBaselineY + m.inkAscent)

        var elements = baseBox.elements
        elements.append(.glyphs(text: glyph, size: accentSize, mono: false,
                                origin: CGPoint(x: (baseBox.width - m.width) / 2, y: accentBaselineY),
                                color: colorOverride))
        return MathBox(width: baseBox.width, ascent: ascent, descent: baseBox.descent, elements: elements)
    }
}
