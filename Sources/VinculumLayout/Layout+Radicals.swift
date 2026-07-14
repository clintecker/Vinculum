import Foundation

extension MathLayoutEngine {

    /// `\sqrt[n]{…}`: a hand-stroked radical sign (tick → downstroke →
    /// upstroke → overline) with the body under the vinculum and the optional
    /// degree tucked into the crook.
    func radicalBox(_ degree: MathNode?, _ radicand: MathNode, size: CGFloat, display: Bool) -> MathBox {
        // The radicand is cramped (an exponent under the root rides lower).
        var radicandEngine = self; radicandEngine.cramped = true
        let body = radicandEngine.box(for: radicand, size: size, display: display)
        let ruleThickness = max(1, size * constants.radicalRuleThickness)
        // The font distinguishes display/text radicand clearance (LM Math:
        // 0.148 vs 0.050 em); the old transcription used the display value
        // everywhere.
        let gap = size * (display ? constants.radicalDisplayStyleVerticalGap
                                  : constants.radicalVerticalGap)
        let signWidth = size * MathLayout.Radical.signWidth
        let degreeBox = degree.map { box(for: $0, size: size * MathLayout.Radical.degreeScale, display: false) }
        let degreeAdvance = degreeBox.map { max(0, $0.width - signWidth * MathLayout.Radical.degreeOverlap) } ?? 0

        let ascent = body.ascent + gap + ruleThickness + size * MathLayout.Radical.extraAscent
        let descent = body.descent
        let width = degreeAdvance + signWidth + body.width + size * MathLayout.Radical.vinculumOverhang

        let signX = degreeAdvance
        let topY = ascent - ruleThickness / 2
        let bottomY = -descent

        var elements: [MathElement] = [stroke([
            .move(CGPoint(x: signX, y: body.height * MathLayout.Radical.tickStartHeight - body.descent)),
            .line(CGPoint(x: signX + signWidth * MathLayout.Radical.shoulderFrac,
                          y: body.height * MathLayout.Radical.notchHeight - body.descent)),
            .line(CGPoint(x: signX + signWidth * MathLayout.Radical.valleyFrac, y: bottomY)),
            .line(CGPoint(x: signX + signWidth, y: topY)),
            .line(CGPoint(x: signX + signWidth + body.width + size * MathLayout.Radical.vinculumOverhang, y: topY)),
        ], width: ruleThickness, cap: .round, join: .miter)]

        elements += body.placed(at: CGPoint(x: signX + signWidth + size * MathLayout.Radical.bodyInset, y: 0))
        if let degreeBox {
            elements += degreeBox.placed(at: CGPoint(x: 0, y: body.height * MathLayout.Radical.degreeRaise - body.descent))
        }
        return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
    }
}
