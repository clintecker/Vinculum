import Foundation

/// Lays a `MathNode` tree out into a platform-free `MathScene`. Geometry only:
/// it measures glyphs through the injected `MathTextMeasurer` and emits
/// positioned primitives, so it runs headless (and on Linux). The per-domain
/// builders live in `Layout+*.swift` extensions; this file is the entry point,
/// the node dispatch, glyph boxes, and TeX inter-atom spacing.
public struct MathLayoutEngine {

    let measure: MathTextMeasurer
    let baseSize: CGFloat
    /// The active `\color` override for the current subtree; `nil` primitives
    /// take the renderer's theme ink.
    var colorOverride: MathColor?
    /// TeX "cramped" style: set under a radical, in a denominator, and on a
    /// subscript. In cramped style superscripts are shifted up less, so an
    /// exponent inside √(x²) or a denominator rides lower. Propagated by
    /// sub-context copies of the engine, like `colorOverride`.
    var cramped = false

    public init(measure: @escaping MathTextMeasurer, baseSize: CGFloat) {
        self.measure = measure
        self.baseSize = baseSize
        self.colorOverride = nil
    }

    /// Lays `node` out at the engine's base size into a device-independent
    /// scene. `display` enables display-style conventions (stacked limits,
    /// larger fraction parts).
    public func layout(_ node: MathNode, display: Bool = false) -> MathScene {
        let box = box(for: node, size: baseSize, display: display)
        return MathScene(width: box.width, ascent: box.ascent, descent: box.descent,
                         elements: box.elements)
    }

    // MARK: - Node dispatch

    func box(for node: MathNode, size s: CGFloat, display: Bool) -> MathBox {
        switch node {
        case .symbol(let glyph, _, let style):
            return glyphBox(glyph, size: s, italic: style == .italic, bold: style == .bold)

        case .functionName(let name):
            return glyphBox(name, size: s, italic: false)

        case .space(let ems):
            return MathBox(width: CGFloat(ems) * s, ascent: 0, descent: 0)

        case .row(let children):
            return rowBox(children, size: s, display: display)

        case .fraction(let numerator, let denominator):
            return fractionBox(numerator, denominator, size: s, display: display)

        case .radical(let degree, let radicand):
            return radicalBox(degree, radicand, size: s, display: display)

        case .scripts(let base, let sub, let sup):
            return scriptsBox(base, sub: sub, sup: sup, size: s, display: display)

        case .delimited(let left, let body, let right):
            return delimitedBox(left, body, right, size: s, display: display)

        case .matrix(let rows, let left, let right, let style):
            return matrixBox(rows, left: left, right: right, style: style, size: s)

        case .accent(let base, let accent):
            return accentBox(base, accent: accent, size: s, display: display)

        case .genfrac(let top, let bottom, let hasRule, let left, let right):
            return genfracBox(top, bottom, hasRule: hasRule, left: left, right: right,
                              size: s, display: display)

        case .overUnder(let base, let over, let under, let kind):
            return overUnderBox(base, over: over, under: under, kind: kind,
                                size: s, display: display)

        case .decorated(let base, let decoration):
            return decoratedBox(base, decoration: decoration, size: s, display: display)

        case .styled(let base, let color):
            // Lay the subtree out with a color override; nested \color nests.
            var sub = self
            sub.colorOverride = MathColor.resolve(color) ?? colorOverride
            return sub.box(for: base, size: s, display: display)

        case .mathStyle(let base, let forced):
            // \dfrac/\tfrac: force the subtree's style regardless of context.
            return box(for: base, size: s, display: forced)

        case .bigDelimiter(let glyph, let factor, _):
            return bigDelimiterBox(glyph, factor: factor, size: s)

        case .unsupported(let source):
            // Callers gate on isFullySupported; draw something sane regardless.
            return glyphBox(source, size: s * MathLayout.unsupportedSourceScale, italic: false, mono: true)
        }
    }

    // MARK: - Glyph boxes

    /// A box holding one glyph run. Style is expressed by remapping to a
    /// Mathematical-Alphanumeric codepoint (`mathVariant`), so the math font
    /// draws true italic/bold; the measurer supplies the metrics.
    func glyphBox(_ text: String, size: CGFloat, italic: Bool, bold: Bool = false, mono: Bool = false) -> MathBox {
        let glyph = mono ? text : Self.mathVariant(text, italic: italic, bold: bold)
        let m = measure(glyph, size, mono)
        let element = MathElement.glyphs(text: glyph, size: size, mono: mono,
                                         origin: CGPoint(x: 0, y: 0), color: colorOverride)
        return MathBox(width: m.width, ascent: m.ascent, descent: m.descent, inkAscent: m.inkAscent,
                       elements: [element])
    }

    /// Remaps a single letter to its Mathematical-Alphanumeric codepoint so
    /// the math font renders proper math italic/bold — LaTeX conventions:
    /// ASCII variables italic (per the style flag), lowercase Greek always
    /// italic, uppercase Greek upright.
    static func mathVariant(_ text: String, italic: Bool, bold: Bool) -> String {
        guard text.unicodeScalars.count == 1, let u = text.unicodeScalars.first else { return text }
        let v = u.value
        func s(_ x: UInt32) -> String { UnicodeScalar(x).map(String.init) ?? text }
        if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) {
            let upper = v <= 0x5A
            let i = v - (upper ? 0x41 : 0x61)
            if bold && italic { return s((upper ? 0x1D468 : 0x1D482) + i) }
            if bold { return s((upper ? 0x1D400 : 0x1D41A) + i) }
            if italic { return v == 0x68 ? "\u{210E}" : s((upper ? 0x1D434 : 0x1D44E) + i) } // ℎ hole
            return text
        }
        if (0x3B1...0x3C9).contains(v) { return s((bold ? 0x1D6C2 : 0x1D6FC) + (v - 0x3B1)) }
        if bold, (0x391...0x3A9).contains(v) { return s(0x1D6A8 + (v - 0x391)) }
        return text
    }

    // MARK: - Rows with TeX spacing

    func rowBox(_ children: [MathNode], size: CGFloat, display: Bool) -> MathBox {
        var boxes: [(box: MathBox, cls: MathAtomClass?)] = []
        for child in children {
            boxes.append((box(for: child, size: size, display: display), atomClass(of: child)))
        }
        let classes = Self.reclassifyBinaries(boxes.map(\.cls))

        var width: CGFloat = 0, ascent: CGFloat = 0, descent: CGFloat = 0
        var placements: [(MathBox, CGFloat)] = []
        var previous: MathAtomClass?

        for (i, entry) in boxes.enumerated() {
            let box = entry.box, cls = classes[i]
            if let previous, let cls {
                width += spacing(between: previous, and: cls) * size
            }
            placements.append((box, width))
            width += box.width
            ascent = max(ascent, box.ascent)
            descent = max(descent, box.descent)
            previous = cls ?? previous
        }

        var elements: [MathElement] = []
        for (box, x) in placements { elements += box.placed(at: CGPoint(x: x, y: 0)) }
        return MathBox(width: width, ascent: ascent, descent: descent, elements: elements)
    }

    func atomClass(of node: MathNode) -> MathAtomClass? {
        switch node {
        case .symbol(_, let cls, _): return cls
        case .functionName: return .largeOperator
        case .fraction, .radical, .delimited, .row, .matrix: return .ordinary
        case .scripts(let base, _, _): return atomClass(of: base)
        case .accent(let base, _): return atomClass(of: base)
        case .genfrac: return .ordinary
        case .overUnder(_, _, _, let kind):
            return (kind == .rightarrow || kind == .leftarrow) ? .relation : .ordinary
        case .decorated(let base, _): return atomClass(of: base)
        case .styled(let base, _): return atomClass(of: base)
        case .mathStyle(let base, _): return atomClass(of: base)
        case .bigDelimiter(_, _, let cls): return cls
        case .space, .unsupported: return nil
        }
    }

    /// TeX's binary/unary reclassification (TeXbook p.170): a Bin atom with no
    /// valid left operand (at the start, or after Bin/Op/Rel/Open/Punct) is
    /// really a unary sign, so it becomes Ord; and a Bin immediately left of a
    /// Rel/Close/Punct becomes Ord too. This is what makes `x = -1` set a thick
    /// space after `=` and a tight unary minus, not a medium space around it.
    /// `nil` classes (spacing/unsupported) don't participate or reset state.
    static func reclassifyBinaries(_ input: [MathAtomClass?]) -> [MathAtomClass?] {
        var classes = input
        var prevIdx: Int?
        for i in classes.indices {
            guard let c = classes[i] else { continue }
            if c == .binary {
                let p = prevIdx.flatMap { classes[$0] }
                if p == nil || p == .binary || p == .largeOperator
                    || p == .relation || p == .opening || p == .punctuation {
                    classes[i] = .ordinary
                }
            } else if c == .relation || c == .closing || c == .punctuation {
                if let pi = prevIdx, classes[pi] == .binary { classes[pi] = .ordinary }
            }
            prevIdx = i
        }
        return classes
    }

    /// TeX inter-atom spacing (in ems): thin 3/18 · medium 4/18 · thick 5/18.
    func spacing(between left: MathAtomClass, and right: MathAtomClass) -> CGFloat {
        let thin = MathSpacing.thin, medium = MathSpacing.medium, thick = MathSpacing.thick
        switch (left, right) {
        case (.ordinary, .binary), (.binary, .ordinary),
             (.closing, .binary), (.binary, .opening),
             (.binary, .largeOperator), (.largeOperator, .binary):
            return medium
        case (.ordinary, .relation), (.relation, .ordinary),
             (.closing, .relation), (.relation, .opening),
             (.largeOperator, .relation), (.relation, .largeOperator):
            return thick
        case (.ordinary, .largeOperator), (.largeOperator, .ordinary),
             (.closing, .largeOperator), (.largeOperator, .opening):
            return thin
        case (.punctuation, _):
            return thin
        default:
            return 0
        }
    }

    // MARK: - Primitive helpers (DRY)

    /// A filled rule (bar/rect) in the current color.
    func rule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> MathElement {
        .rule(CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height)),
              color: colorOverride)
    }

    /// A stroked path in the current color.
    func stroke(_ ops: [PathOp], width: CGFloat,
                cap: StrokeCap = .round, join: StrokeJoin = .miter) -> MathElement {
        .stroke(path: ops, width: width, cap: cap, join: join, color: colorOverride)
    }
}
