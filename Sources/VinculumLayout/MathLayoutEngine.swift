import Foundation

/// Lays a `MathNode` tree out into a platform-free `MathScene`. Geometry only:
/// it measures glyphs through the injected `MathTextMeasurer` and emits
/// positioned primitives, so it runs headless (and on Linux). The per-domain
/// builders live in `Layout+*.swift` extensions; this file is the entry point,
/// the node dispatch, glyph boxes, and TeX inter-atom spacing.
public struct MathLayoutEngine {

    let measure: MathTextMeasurer
    /// Optional MATH-table delimiter variant provider; `nil` → continuous
    /// glyph scaling (the platform-free / headless default).
    let delimiters: MathDelimiterProvider?
    /// Optional MATH-table glyph assembly for heights beyond the largest
    /// size variant; `nil` → fall through to scaling.
    let delimiterAssembly: MathDelimiterAssemblyProvider?
    let baseSize: CGFloat
    /// The font's MATH-table constants. Defaults to Latin Modern Math's
    /// values (`.latinModern`) so headless hosts need no font; the renderer
    /// passes constants parsed from the live font (`MathTableParser`).
    let constants: MathFontConstants
    /// Optional per-glyph typography (italic correction, accent attachment,
    /// cut-in kerns); `nil` → neutral defaults (headless default).
    let typography: MathGlyphTypographyProvider?
    /// The active `\color` override for the current subtree; `nil` primitives
    /// take the renderer's theme ink.
    var colorOverride: MathColor?
    /// TeX "cramped" style: set under a radical, in a denominator, and on a
    /// subscript. In cramped style superscripts are shifted up less, so an
    /// exponent inside √(x²) or a denominator rides lower. Propagated by
    /// sub-context copies of the engine, like `colorOverride`.
    var cramped = false

    public init(measure: @escaping MathTextMeasurer, baseSize: CGFloat,
                delimiters: MathDelimiterProvider? = nil,
                constants: MathFontConstants = .latinModern,
                typography: MathGlyphTypographyProvider? = nil,
                delimiterAssembly: MathDelimiterAssemblyProvider? = nil) {
        self.measure = measure
        self.delimiters = delimiters
        self.delimiterAssembly = delimiterAssembly
        self.baseSize = baseSize
        self.constants = constants
        self.typography = typography
        self.colorOverride = nil
    }

    /// Per-glyph typography of a node that renders as a single glyph run —
    /// the italic correction and kern data scripts attach against. Composite
    /// nodes (fractions, fenced bodies…) have none; transparents unwrap.
    func glyphTypography(of node: MathNode, size: CGFloat) -> GlyphTypography? {
        guard let typography else { return nil }
        switch node {
        case .symbol(let glyph, _, let style):
            let rendered = Self.mathVariant(glyph, italic: style == .italic, bold: style == .bold)
            return typography(rendered, size)
        case .classified(let base, _), .limitsOperator(let base):
            return glyphTypography(of: base, size: size)
        default:
            return nil
        }
    }

    /// Lays `node` out at the engine's base size into a device-independent
    /// scene. `display` enables display-style conventions (stacked limits,
    /// larger fraction parts).
    public func layout(_ node: MathNode, display: Bool = false) -> MathScene {
        let box = box(for: node, size: baseSize, style: display ? .display : .text)
        return MathScene(width: box.width, ascent: box.ascent, descent: box.descent,
                         elements: box.elements)
    }

    // MARK: - Node dispatch

    func box(for node: MathNode, size s: CGFloat, style: MathStyle) -> MathBox {
        switch node {
        case .symbol(let glyph, let cls, let symbolStyle):
            // TeX Rule 13: in display style a large operator swaps in the
            // font's display-size variant (DisplayOperatorMinHeight),
            // centered on the math axis.
            if cls == .largeOperator, style.isDisplay, let opBox = largeOperatorBox(glyph, size: s) {
                return opBox
            }
            return glyphBox(glyph, size: s, italic: symbolStyle == .italic, bold: symbolStyle == .bold)

        case .functionName(let name):
            return glyphBox(name, size: s, italic: false)

        case .limitsOperator(let base):
            return box(for: base, size: s, style: style)   // transparent; limits handled in scriptsBox

        case .classified(let base, _):
            return box(for: base, size: s, style: style)   // transparent; only the atom class changes

        case .ruleBox(let w, let h):
            let ww = CGFloat(w) * s, hh = CGFloat(h) * s
            return MathBox(width: ww, ascent: hh, descent: 0, elements: [rule(x: 0, y: 0, width: ww, height: hh)])

        case .raised(let base, let shift):
            let b = box(for: base, size: s, style: style)
            let dy = CGFloat(shift) * s
            return MathBox(width: b.width, ascent: b.ascent + dy, descent: b.descent - dy,
                           inkAscent: b.inkAscent + dy, elements: b.placed(at: CGPoint(x: 0, y: dy)))

        case .colorbox(let base, let bg, let border):
            return colorboxBox(base, background: bg, border: border, size: s, style: style)

        case .space(let ems):
            return MathBox(width: CGFloat(ems) * s, ascent: 0, descent: 0)

        case .row(let children):
            return rowBox(children, size: s, style: style)

        case .fraction(let numerator, let denominator):
            return fractionBox(numerator, denominator, size: s, style: style)

        case .cfrac(let num, let den, let align):
            return cfracBox(num, den, align: align, size: s)

        case .radical(let degree, let radicand):
            return radicalBox(degree, radicand, size: s, style: style)

        case .scripts(let base, let sub, let sup):
            // TeX Rule 12: scripts on an accented single character move onto
            // the character itself — \hat{f}^2 puts the ² on the f, under
            // the hat's reach, not after the accent box.
            if case .accent(let inner, let acc) = base, acc.glyph != nil,
               case .symbol = inner {
                return accentBox(inner, accent: acc, size: s, style: style, scripts: (sub, sup))
            }
            return scriptsBox(base, sub: sub, sup: sup, size: s, style: style)

        case .delimited(let left, let body, let right):
            return delimitedBox(left, body, right, size: s, style: style)

        case .fenced(let fences, let segments):
            return fencedBox(fences, segments, size: s, style: style)

        case .matrix(let rows, let left, let right, let style):
            return matrixBox(rows, left: left, right: right, style: style, size: s)

        case .accent(let base, let accent):
            return accentBox(base, accent: accent, size: s, style: style)

        case .genfrac(let top, let bottom, let hasRule, let left, let right):
            return genfracBox(top, bottom, hasRule: hasRule, left: left, right: right,
                              size: s, style: style)

        case .overUnder(let base, let over, let under, let kind):
            return overUnderBox(base, over: over, under: under, kind: kind,
                                size: s, style: style)

        case .decorated(let base, let decoration):
            return decoratedBox(base, decoration: decoration, size: s, style: style)

        case .styled(let base, let color):
            // Lay the subtree out with a color override; nested \color nests.
            var sub = self
            sub.colorOverride = MathColor.resolve(color) ?? colorOverride
            return sub.box(for: base, size: s, style: style)

        case .mathStyle(let base, let forced):
            // \dfrac/\tfrac/\genfrac style/\displaystyle…: force the
            // subtree's style — and the size that style implies (so
            // \scriptstyle shrinks and \displaystyle inside a script grows
            // back to full size).
            let factor = forced.sizeFactor(constants) / style.sizeFactor(constants)
            return box(for: base, size: s * factor, style: forced)

        case .bigDelimiter(let glyph, let factor, _):
            return bigDelimiterBox(glyph, factor: factor, size: s)

        case .unsupported(let source):
            // Callers gate on isFullySupported; draw something sane regardless.
            return glyphBox(source, size: s * MathLayout.unsupportedSourceScale, italic: false, mono: true)
        }
    }

    /// The font's display-size variant of a large operator (∑, ∫, …) at
    /// `DisplayOperatorMinHeight`, centered on the math axis (TeX's
    /// `½(h − d) − a` shift). Nil headless or when the font has no variant.
    func largeOperatorBox(_ glyph: String, size: CGFloat) -> MathBox? {
        guard let provider = delimiters,
              let shape = provider(glyph, size * constants.displayOperatorMinHeight, size)
        else { return nil }
        let m = shape.metrics
        let offset = size * constants.axisHeight - (m.ascent - m.descent) / 2
        return MathBox(width: m.width, ascent: m.ascent + offset, descent: m.descent - offset,
                       inkAscent: m.inkAscent + offset,
                       elements: [.glyph(id: shape.glyphID, size: size,
                                         origin: CGPoint(x: 0, y: offset), color: colorOverride)])
    }

    /// TeX Rule 19's fence height: ψ measured from the axis, covered to at
    /// least `\delimiterfactor`/1000 of full (901 → 90.1%) or within
    /// `\delimitershortfall` (5 pt) of it, whichever demands more.
    func fenceTarget(ascent: CGFloat, descent: CGFloat, size: CGFloat) -> CGFloat {
        let axis = size * constants.axisHeight
        let psi = max(ascent - axis, descent + axis)
        return max(psi * 2 * 0.901, 2 * psi - 5)
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

    func rowBox(_ children: [MathNode], size: CGFloat, style: MathStyle) -> MathBox {
        var boxes: [(box: MathBox, cls: MathAtomClass?)] = []
        for child in children {
            boxes.append((box(for: child, size: size, style: style), atomClass(of: child)))
        }
        let classes = Self.reclassifyBinaries(boxes.map(\.cls))

        var width: CGFloat = 0, ascent: CGFloat = 0, descent: CGFloat = 0
        var placements: [(MathBox, CGFloat)] = []
        var previous: MathAtomClass?

        for (i, entry) in boxes.enumerated() {
            let box = entry.box, cls = classes[i]
            if let previous, let cls {
                width += spacing(between: previous, and: cls, style: style) * size
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
        case .limitsOperator(let base): return atomClass(of: base)
        case .classified(_, let cls): return cls
        case .raised(let base, _): return atomClass(of: base)
        case .fraction, .cfrac, .radical, .delimited, .fenced, .row, .matrix,
             .ruleBox, .colorbox: return .ordinary
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
    /// Medium and thick are parenthesized in TeX's chart (ch. 18) — they
    /// vanish in script styles; thin space applies in every style.
    func spacing(between left: MathAtomClass, and right: MathAtomClass,
                 style: MathStyle = .text) -> CGFloat {
        let thin = MathSpacing.thin
        let medium = style.isScriptLevel ? 0 : MathSpacing.medium
        let thick = style.isScriptLevel ? 0 : MathSpacing.thick
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
