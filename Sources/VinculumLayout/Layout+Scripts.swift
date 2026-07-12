import Foundation

extension MathLayoutEngine {

    /// Sub/superscripts. In display style a big operator takes its scripts as
    /// stacked limits (∑ᵢ₌₁ⁿ), like TeX's `\limits`; otherwise they sit to the
    /// right of the base.
    func scriptsBox(_ base: MathNode, sub: MathNode?, sup: MathNode?,
                    size: CGFloat, display: Bool) -> MathBox {
        if display, case .symbol(_, .largeOperator, _) = base {
            return limitsBox(base, sub: sub, sup: sup, size: size)
        }
        let baseBox = box(for: base, size: size, display: display)
        let scriptSize = size * 0.68
        let supBox = sup.map { box(for: $0, size: scriptSize, display: false) }
        let subBox = sub.map { box(for: $0, size: scriptSize, display: false) }

        let supRaise = size * 0.42
        let subDrop = size * 0.20
        let scriptsWidth = max(supBox?.width ?? 0, subBox?.width ?? 0)
        let width = baseBox.width + scriptsWidth + size * 0.03

        var ascent = baseBox.ascent
        var descent = baseBox.descent
        if let supBox { ascent = max(ascent, supRaise + supBox.ascent) }
        if let subBox { descent = max(descent, subDrop + subBox.descent) }

        var elements = baseBox.elements
        let scriptX = baseBox.width + size * 0.03
        if let supBox { elements += supBox.placed(at: CGPoint(x: scriptX, y: supRaise)) }
        if let subBox { elements += subBox.placed(at: CGPoint(x: scriptX, y: -subDrop)) }
        return MathBox(width: width, ascent: ascent, descent: descent,
                       inkAscent: baseBox.inkAscent, elements: elements)
    }

    /// ∑/∫-style stacked limits: the operator enlarged, superscript centered
    /// above, subscript centered below.
    func limitsBox(_ base: MathNode, sub: MathNode?, sup: MathNode?, size: CGFloat) -> MathBox {
        let opBox = box(for: base, size: size * 1.35, display: false)
        let scriptSize = size * 0.68
        let supBox = sup.map { box(for: $0, size: scriptSize, display: false) }
        let subBox = sub.map { box(for: $0, size: scriptSize, display: false) }
        let gap = size * 0.12

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
}
