import Foundation

extension MathLayoutEngine {

    /// Material set over/under a base: `\overset`/`\underset` (plain stacking),
    /// `\overbrace`/`\underbrace` (a drawn brace + label), and `\xrightarrow`/
    /// `\xleftarrow` (a stretchy arrow sized to its annotations).
    func overUnderBox(_ base: MathNode, over: MathNode?, under: MathNode?,
                      kind: MathOverUnder, size: CGFloat, display: Bool) -> MathBox {
        let annotationSize = size * MathConstants.scriptPercentScaleDown
        let overBox = over.map { box(for: $0, size: annotationSize, display: false) }
        let underBox = under.map { box(for: $0, size: annotationSize, display: false) }
        let gap = size * MathLayout.overUnderGap

        switch kind {
        case .rightarrow, .leftarrow:
            let labelWidth = max(overBox?.width ?? 0, underBox?.width ?? 0)
            let arrowWidth = max(size * MathLayout.Arrow.minWidth, labelWidth + size * MathLayout.Arrow.labelPadding)
            let arrowThickness = max(1, size * MathConstants.defaultRuleThickness)
            let headLength = size * MathLayout.Arrow.headLength
            let axis = size * MathConstants.axisHeight
            var ascent = axis + arrowThickness / 2
            var descent = arrowThickness / 2 - axis
            if let overBox { ascent += gap + overBox.height }
            if let underBox { descent += gap + underBox.height }
            let left = kind == .leftarrow
            let tipX = left ? 0 : arrowWidth
            let dir: CGFloat = left ? 1 : -1

            var elements: [MathElement] = [stroke([
                .move(CGPoint(x: 0, y: axis)), .line(CGPoint(x: arrowWidth, y: axis)),
                .move(CGPoint(x: tipX + dir * headLength, y: axis + headLength * 0.5)),
                .line(CGPoint(x: tipX, y: axis)),
                .line(CGPoint(x: tipX + dir * headLength, y: axis - headLength * 0.5)),
            ], width: arrowThickness, cap: .round)]
            if let overBox {
                elements += overBox.placed(at: CGPoint(x: (arrowWidth - overBox.width) / 2,
                                                       y: axis + arrowThickness / 2 + gap + overBox.descent))
            }
            if let underBox {
                elements += underBox.placed(at: CGPoint(x: (arrowWidth - underBox.width) / 2,
                                                        y: axis - arrowThickness / 2 - gap - underBox.ascent))
            }
            return MathBox(width: arrowWidth, ascent: ascent, descent: max(descent, 0), elements: elements)

        case .overbrace, .underbrace:
            let baseBox = box(for: base, size: size, display: display)
            let braceHeight = size * MathLayout.Brace.height
            let isOver = kind == .overbrace
            let label = isOver ? overBox : underBox
            var ascent = baseBox.ascent
            var descent = baseBox.descent
            if isOver {
                ascent += gap + braceHeight + (label.map { gap + $0.height } ?? 0)
            } else {
                descent += gap + braceHeight + (label.map { gap + $0.height } ?? 0)
            }
            let width = max(baseBox.width, label?.width ?? 0)

            var elements = baseBox.placed(at: CGPoint(x: (width - baseBox.width) / 2, y: 0))
            let braceY = isOver ? baseBox.ascent + gap : -baseBox.descent - gap - braceHeight
            elements.append(horizontalBrace(x: 0, y: braceY, width: width,
                                            height: braceHeight, pointingUp: isOver))
            if let label {
                let labelY = isOver ? braceY + braceHeight + gap + label.descent
                                    : braceY - gap - label.ascent
                elements += label.placed(at: CGPoint(x: (width - label.width) / 2, y: labelY))
            }
            return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)

        case .plain:
            let baseBox = box(for: base, size: size, display: display)
            let width = max(baseBox.width, overBox?.width ?? 0, underBox?.width ?? 0)
            var ascent = baseBox.ascent
            var descent = baseBox.descent
            if let overBox { ascent += gap + overBox.height }
            if let underBox { descent += gap + underBox.height }
            var elements = baseBox.placed(at: CGPoint(x: (width - baseBox.width) / 2, y: 0))
            if let overBox {
                elements += overBox.placed(at: CGPoint(x: (width - overBox.width) / 2,
                                                       y: baseBox.ascent + gap + overBox.descent))
            }
            if let underBox {
                elements += underBox.placed(at: CGPoint(x: (width - underBox.width) / 2,
                                                        y: -baseBox.descent - gap - underBox.ascent))
            }
            return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
        }
    }

    /// A horizontal curly brace spanning `width`, as four quadratic arcs with
    /// a center notch — the same hand-stroked approach as the radical.
    private func horizontalBrace(x: CGFloat, y: CGFloat, width: CGFloat,
                                 height: CGFloat, pointingUp: Bool) -> MathElement {
        let thickness = max(1, height * MathLayout.Brace.thicknessFrac)
        let notch = pointingUp ? y + height : y            // tip toward the label
        let shoulder = pointingUp ? y : y + height         // ends toward the base
        let midX = x + width / 2
        return stroke([
            .move(CGPoint(x: x, y: shoulder)),
            .quad(to: CGPoint(x: x + width * MathLayout.Brace.leftArcEnd, y: (shoulder + notch) * 0.5),
                  control: CGPoint(x: x + width * MathLayout.Brace.leftArcControl, y: shoulder)),
            .quad(to: CGPoint(x: midX, y: notch),
                  control: CGPoint(x: x + width * MathLayout.Brace.leftNotchControl, y: notch)),
            .quad(to: CGPoint(x: x + width * MathLayout.Brace.rightArcEnd, y: (shoulder + notch) * 0.5),
                  control: CGPoint(x: x + width * MathLayout.Brace.rightNotchControl, y: notch)),
            .quad(to: CGPoint(x: x + width, y: shoulder),
                  control: CGPoint(x: x + width * MathLayout.Brace.rightArcControl, y: shoulder)),
        ], width: thickness, cap: .round)
    }
}
