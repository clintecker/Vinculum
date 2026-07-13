import Foundation

extension MathLayoutEngine {

    /// Sub/superscripts. In display style a big operator takes its scripts as
    /// stacked limits (∑ᵢ₌₁ⁿ), like TeX's `\limits`; otherwise they sit to the
    /// right of the base.
    func scriptsBox(_ base: MathNode, sub: MathNode?, sup: MathNode?,
                    size: CGFloat, display: Bool) -> MathBox {
        if display, takesDisplayLimits(base) {
            // Symbol operators (∑, ∏) enlarge; named ones (lim, max) stay text-size.
            let enlarge: Bool
            if case .symbol(_, .largeOperator, _) = base { enlarge = true } else { enlarge = false }
            return limitsBox(base, sub: sub, sup: sup, size: size, enlarge: enlarge)
        }
        let baseBox = box(for: base, size: size, display: display)
        let scriptSize = size * MathConstants.scriptPercentScaleDown
        // A superscript is uncramped; a subscript is cramped (TeX sup_style /
        // sub_style), so nested exponents inside a subscript ride lower.
        var supEngine = self; supEngine.cramped = false
        var subEngine = self; subEngine.cramped = true
        let supBox = sup.map { supEngine.box(for: $0, size: scriptSize, display: false) }
        let subBox = sub.map { subEngine.box(for: $0, size: scriptSize, display: false) }

        // TeX Appendix G: take the nominal shift (lower in cramped style), but
        // raise it so the script clears a tall base's ink — an exponent on (…)²
        // rides above the paren, not through it — and keep a minimum gap
        // between a coexisting super- and subscript so they can't collide.
        let supNominal = size * (cramped ? MathConstants.superscriptShiftUpCramped
                                         : MathConstants.superscriptShiftUp)
        let supRaise = max(supNominal, baseBox.inkAscent - scriptSize * 0.25)
        var subDrop = max(size * MathConstants.subscriptShiftDown,
                          baseBox.descent + scriptSize * 0.15)
        if let supBox, let subBox {
            let minGap = size * 4 * MathConstants.defaultRuleThickness
            let gap = (supRaise - supBox.descent) - (subBox.ascent - subDrop)
            if gap < minGap { subDrop += minGap - gap }
        }
        let scriptsWidth = max(supBox?.width ?? 0, subBox?.width ?? 0)
        let width = baseBox.width + scriptsWidth + size * MathConstants.spaceAfterScript

        var ascent = baseBox.ascent
        var descent = baseBox.descent
        if let supBox { ascent = max(ascent, supRaise + supBox.ascent) }
        if let subBox { descent = max(descent, subDrop + subBox.descent) }

        var elements = baseBox.elements
        let scriptX = baseBox.width + size * MathConstants.spaceAfterScript
        if let supBox { elements += supBox.placed(at: CGPoint(x: scriptX, y: supRaise)) }
        if let subBox { elements += subBox.placed(at: CGPoint(x: scriptX, y: -subDrop)) }
        return MathBox(width: width, ascent: ascent, descent: descent,
                       inkAscent: baseBox.inkAscent, elements: elements)
    }

    /// ∑/∫-style stacked limits: the operator enlarged, superscript centered
    /// above, subscript centered below.
    func limitsBox(_ base: MathNode, sub: MathNode?, sup: MathNode?, size: CGFloat, enlarge: Bool) -> MathBox {
        let opBox = box(for: base, size: enlarge ? size * MathLayout.displayOperatorScale : size, display: false)
        let scriptSize = size * MathConstants.scriptPercentScaleDown
        let supBox = sup.map { box(for: $0, size: scriptSize, display: false) }
        let subBox = sub.map { box(for: $0, size: scriptSize, display: false) }
        let gap = size * MathConstants.stackGapMin

        let width = max(opBox.width, supBox?.width ?? 0, subBox?.width ?? 0)
        var ascent = opBox.ascent
        var descent = opBox.descent
        if let supBox { ascent += gap + supBox.height }
        if let subBox { descent += gap + subBox.height }

        var elements = opBox.placed(at: CGPoint(x: (width - opBox.width) / 2, y: 0))
        if let supBox {
            elements += supBox.placed(at: CGPoint(x: (width - supBox.width) / 2,
                                                  y: opBox.ascent + gap + supBox.descent))
        }
        if let subBox {
            elements += subBox.placed(at: CGPoint(x: (width - subBox.width) / 2,
                                                  y: -opBox.descent - gap - subBox.ascent))
        }
        return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
    }

    // Integral-family glyphs default to \nolimits in TeX: their scripts stay to
    // the side even in display style (∫₀¹, not a stacked lower/upper limit).
    private static let integralGlyphs: Set<Character> = ["∫", "∬", "∭", "⨌", "∮", "∯", "∰", "∱", "∲", "∳"]
    // Named operators that DO take stacked limits (unlike \sin, \log, \cos …).
    private static let limitFunctionNames: Set<String> = [
        "lim", "max", "min", "sup", "inf", "det", "gcd", "Pr",
        "limsup", "liminf", "injlim", "projlim",
        "varinjlim", "varprojlim", "varliminf", "varlimsup", "argmax", "argmin"]

    /// Whether an operator stacks its scripts as over/under limits in display
    /// style. Symbol operators do (∑, ∏, ⋃) except integrals; among the upright
    /// function names, only the lim/max family does.
    func takesDisplayLimits(_ base: MathNode) -> Bool {
        switch base {
        case let .symbol(glyph, .largeOperator, _):
            return !(glyph.count == 1 && Self.integralGlyphs.contains(glyph[glyph.startIndex]))
        case let .functionName(name):
            return Self.limitFunctionNames.contains(name)
        case .limitsOperator:
            return true                       // \operatorname* always stacks
        case let .classified(_, cls):
            return cls == .largeOperator      // \mathop takes limits
        default:
            return false
        }
    }
}
