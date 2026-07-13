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
        let topBox = box(for: top, size: partSize, display: false)
        let bottomBox = box(for: bottom, size: partSize, display: false)

        let ruleThickness = hasRule ? max(1, size * MathConstants.fractionRuleThickness) : 0
        let gap = size * (hasRule ? MathLayout.Fraction.ruleGap : MathLayout.Fraction.atopGap)
        let axis = size * MathConstants.axisHeight
        let width = max(topBox.width, bottomBox.width) + size * MathLayout.Fraction.sidePadding
        let ascent = axis + ruleThickness / 2 + gap + topBox.height
        // Mirror of `ascent` about the axis: the denominator's bottom sits
        // gap + half-rule below the axis, plus its own height.
        let descent = bottomBox.height + gap - axis + ruleThickness / 2

        var elements: [MathElement] = []
        if hasRule {
            elements.append(rule(x: size * MathLayout.Fraction.ruleInset, y: axis - ruleThickness / 2,
                                 width: width - size * MathLayout.Fraction.ruleInset * 2, height: ruleThickness))
        }
        elements += topBox.placed(at: CGPoint(x: (width - topBox.width) / 2,
                                              y: axis + ruleThickness / 2 + gap + topBox.descent))
        elements += bottomBox.placed(at: CGPoint(x: (width - bottomBox.width) / 2,
                                                 y: axis - ruleThickness / 2 - gap - bottomBox.ascent))
        let stack = MathBox(width: width, ascent: ascent, descent: descent, elements: elements)

        guard !left.isEmpty || !right.isEmpty else { return stack }
        return delimitedBoxAround(stack, left: left, right: right, size: size)
    }
}
