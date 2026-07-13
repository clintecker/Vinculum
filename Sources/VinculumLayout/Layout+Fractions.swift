import Foundation

extension MathLayoutEngine {

    /// `\frac`: numerator over denominator, separated by a rule. It is exactly
    /// a ruled `genfrac` with no fences — one stacking implementation, kept DRY.
    func fractionBox(_ numerator: MathNode, _ denominator: MathNode,
                     size: CGFloat, display: Bool) -> MathBox {
        genfracBox(numerator, denominator, hasRule: true, left: "", right: "",
                   size: size, display: display)
    }

    /// `\binom` and ruleless stacks: numerator over denominator with an
    /// optional rule and optional enclosing fences.
    func genfracBox(_ top: MathNode, _ bottom: MathNode, hasRule: Bool,
                    left: String, right: String, size: CGFloat, display: Bool) -> MathBox {
        let partSize = size * (display ? MathLayout.Fraction.partScaleDisplay
                                       : MathLayout.Fraction.partScaleText)
        // Numerator uncramped, denominator cramped (TeX num_style / denom_style)
        // — so an exponent in the denominator rides lower than in the numerator.
        var numEngine = self; numEngine.cramped = false
        var denEngine = self; denEngine.cramped = true
        let topBox = numEngine.box(for: top, size: partSize, display: false)
        let bottomBox = denEngine.box(for: bottom, size: partSize, display: false)

        let ruleThickness = hasRule ? max(1, size * MathConstants.fractionRuleThickness) : 0
        let axis = size * MathConstants.axisHeight
        let width = max(topBox.width, bottomBox.width) + size * MathLayout.Fraction.sidePadding

        // TeX shift-model (Appendix G rules 15): position each part by a NOMINAL
        // baseline shift (the font's MATH-table values) so a short `1` and a
        // deep numerator share the same baseline, then increase the shift only
        // as needed to keep a minimum gap from the rule. Stable, TeX-like.
        let displayBoost: CGFloat = display ? 1.35 : 1.0
        var shiftUp = size * MathConstants.fractionNumeratorShiftUp * displayBoost
        var shiftDown = size * MathConstants.fractionDenominatorShiftDown * displayBoost
        if hasRule {
            let minGap = size * MathLayout.Fraction.ruleGap
            let numClear = (shiftUp - topBox.descent) - (axis + ruleThickness / 2)
            if numClear < minGap { shiftUp += minGap - numClear }
            let denClear = (axis - ruleThickness / 2) - (bottomBox.ascent - shiftDown)
            if denClear < minGap { shiftDown += minGap - denClear }
        } else {
            let minGap = size * MathLayout.Fraction.atopGap
            let gap = (shiftUp - topBox.descent) - (bottomBox.ascent - shiftDown)
            if gap < minGap { let d = (minGap - gap) / 2; shiftUp += d; shiftDown += d }
        }

        let ascent = shiftUp + topBox.ascent
        let descent = shiftDown + bottomBox.descent

        var elements: [MathElement] = []
        if hasRule {
            elements.append(rule(x: size * MathLayout.Fraction.ruleInset, y: axis - ruleThickness / 2,
                                 width: width - size * MathLayout.Fraction.ruleInset * 2, height: ruleThickness))
        }
        elements += topBox.placed(at: CGPoint(x: (width - topBox.width) / 2, y: shiftUp))
        elements += bottomBox.placed(at: CGPoint(x: (width - bottomBox.width) / 2, y: -shiftDown))
        let stack = MathBox(width: width, ascent: ascent, descent: descent, elements: elements)

        guard !left.isEmpty || !right.isEmpty else { return stack }
        return delimitedBoxAround(stack, left: left, right: right, size: size)
    }
}
