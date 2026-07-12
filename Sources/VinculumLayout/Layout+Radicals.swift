import Foundation

extension MathLayoutEngine {

    /// `\sqrt[n]{…}`: a hand-stroked radical sign (tick → downstroke →
    /// upstroke → overline) with the body under the vinculum and the optional
    /// degree tucked into the crook.
    func radicalBox(_ degree: MathNode?, _ radicand: MathNode, size: CGFloat, display: Bool) -> MathBox {
        let body = box(for: radicand, size: size, display: display)
        let ruleThickness = max(1, size * 0.045)
        let gap = size * 0.12
        let signWidth = size * 0.55
        let degreeBox = degree.map { box(for: $0, size: size * 0.6, display: false) }
        let degreeAdvance = degreeBox.map { max(0, $0.width - signWidth * 0.35) } ?? 0

        let ascent = body.ascent + gap + ruleThickness + size * 0.06
        let descent = body.descent
        let width = degreeAdvance + signWidth + body.width + size * 0.12

        let signX = degreeAdvance
        let topY = ascent - ruleThickness / 2
        let bottomY = -descent

        var elements: [MathElement] = [stroke([
            .move(CGPoint(x: signX, y: body.height * 0.25 - body.descent)),
            .line(CGPoint(x: signX + signWidth * 0.3, y: body.height * 0.12 - body.descent)),
            .line(CGPoint(x: signX + signWidth * 0.55, y: bottomY)),
            .line(CGPoint(x: signX + signWidth, y: topY)),
            .line(CGPoint(x: signX + signWidth + body.width + size * 0.12, y: topY)),
        ], width: ruleThickness, cap: .round, join: .miter)]

        elements += body.placed(at: CGPoint(x: signX + signWidth + size * 0.06, y: 0))
        if let degreeBox {
            elements += degreeBox.placed(at: CGPoint(x: 0, y: body.height * 0.45 - body.descent))
        }
        return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
    }
}
