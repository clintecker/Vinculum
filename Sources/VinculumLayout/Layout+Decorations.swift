import Foundation

extension MathLayoutEngine {

    /// `\boxed` (a stroked frame with padding) and the `\phantom` family
    /// (reserve space, draw nothing).
    func decoratedBox(_ base: MathNode, decoration: MathDecoration,
                      size: CGFloat, display: Bool) -> MathBox {
        let baseBox = box(for: base, size: size, display: display)
        switch decoration {
        case .phantom:
            return MathBox(width: baseBox.width, ascent: baseBox.ascent, descent: baseBox.descent)
        case .hphantom:
            return MathBox(width: baseBox.width, ascent: 0, descent: 0)
        case .vphantom:
            return MathBox(width: 0, ascent: baseBox.ascent, descent: baseBox.descent)
        case .boxed:
            let pad = size * 0.18
            let line = max(1, size * 0.04)
            let width = baseBox.width + pad * 2
            let ascent = baseBox.ascent + pad
            let descent = baseBox.descent + pad
            var elements = baseBox.placed(at: CGPoint(x: pad, y: 0))
            // A closed rectangle stroked centered on its edge (== stroke(rect)).
            let rx = line / 2, ry = -descent + line / 2
            let rw = width - line, rh = ascent + descent - line
            elements.append(stroke([
                .move(CGPoint(x: rx, y: ry)),
                .line(CGPoint(x: rx + rw, y: ry)),
                .line(CGPoint(x: rx + rw, y: ry + rh)),
                .line(CGPoint(x: rx, y: ry + rh)),
                .close,
            ], width: line, cap: .butt, join: .miter))
            return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
        }
    }
}
