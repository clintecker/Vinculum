import Foundation

/// A parsed LaTeX math expression. The node tree is deliberately close to
/// TeX's own model — rows of atoms with spacing classes — so the layout
/// engine can apply real inter-atom spacing rules instead of guessing.
public indirect enum MathNode: Hashable, Sendable {
    /// A single glyph run (variable, digit, symbol) with its TeX atom class.
    case symbol(String, MathAtomClass, style: MathSymbolStyle = .italic)
    /// Horizontal sequence.
    case row([MathNode])
    case fraction(numerator: MathNode, denominator: MathNode)
    case radical(degree: MathNode?, radicand: MathNode)
    case scripts(base: MathNode, subscript: MathNode?, superscript: MathNode?)
    /// Auto-sized fences around a body: ( ) [ ] { } | ‖.
    case delimited(left: String, body: MathNode, right: String)
    /// A grid of cells from a `\begin{…}…\end{…}` environment — matrices,
    /// `cases`, `aligned`. `left`/`right` are the enclosing fences (empty for
    /// none); `style` selects column alignment.
    case matrix(rows: [[MathNode]], left: String, right: String, style: MathMatrixStyle)
    /// Upright function name (sin, log …).
    case functionName(String)
    /// Explicit spacing (multiples of an em quad).
    case space(Double)
    /// An accent over (or rule under) a base: \hat \vec \bar \overline …
    case accent(base: MathNode, accent: MathAccent)
    /// Generalized fraction: numerator over denominator with an optional
    /// rule and optional enclosing fences. `\frac` is rule-yes/no-fence;
    /// `\binom` is rule-no/paren-fence.
    case genfrac(top: MathNode, bottom: MathNode, hasRule: Bool, left: String, right: String)
    /// Material set over and/or under a base: \overset \underset \stackrel
    /// (plain), \overbrace \underbrace (a drawn brace), \xrightarrow
    /// \xleftarrow (a stretchy arrow). `over`/`under` are the annotations.
    case overUnder(base: MathNode, over: MathNode?, under: MathNode?, kind: MathOverUnder)
    /// A box/spacing decoration: \boxed (framed) or the \phantom family
    /// (reserve space, draw nothing).
    case decorated(base: MathNode, decoration: MathDecoration)
    /// A recolored subexpression: \color / \textcolor. The color is a name
    /// ("red", "teal") or "#rrggbb"; the renderer resolves it.
    case styled(base: MathNode, color: String)
    /// A subexpression forced into display or text style regardless of the
    /// ambient context: \dfrac / \tfrac (display/text fraction) and
    /// \dbinom / \tbinom.
    case mathStyle(base: MathNode, display: Bool)
    /// A lone delimiter glyph at an explicit size: \big \Big \bigg \Bigg
    /// (+ `l`/`r`/`m`). `factor` is the target height as a multiple of the
    /// base size; `atomClass` is the spacing class the suffix selects.
    case bigDelimiter(glyph: String, factor: CGFloat, atomClass: MathAtomClass)
    /// Something we don't understand — rendered as literal marked source
    /// (the PRD rule: unknown input degrades, never errors).
    case unsupported(String)
}

/// A `.decorated` treatment: a frame or reserved (invisible) space.
public enum MathDecoration: Hashable, Sendable {
    case boxed        // \boxed — stroked frame with padding
    case phantom      // reserve full box, draw nothing
    case hphantom     // reserve width only
    case vphantom     // reserve height only
}

/// How an `.overUnder` decoration is drawn between base and annotations.
public enum MathOverUnder: Hashable, Sendable {
    case plain        // \overset / \underset / \stackrel — bare stacking
    case overbrace    // ⏞ drawn above the base
    case underbrace   // ⏟ drawn below the base
    case rightarrow   // stretchy → with the annotation(s) over/under it
    case leftarrow    // stretchy ←
}

/// An accent decoration placed over (or, for rules, over/under) a base.
public enum MathAccent: Hashable, Sendable {
    case hat, check, tilde, bar, vec, dot, ddot, breve, mathring, acute, grave
    case widehat, widetilde   // stretchy variants
    case overline, underline  // drawn rules, not glyphs

    /// The glyph drawn above the base (nil for the rule accents).
    public var glyph: String? {
        switch self {
        case .hat, .widehat: return "^"
        case .check: return "ˇ"
        case .tilde, .widetilde: return "~"
        case .bar: return "‾"
        case .vec: return "⃗"
        case .dot: return "˙"
        case .ddot: return "¨"
        case .breve: return "˘"
        case .mathring: return "˚"
        case .acute: return "´"
        case .grave: return "`"
        case .overline, .underline: return nil
        }
    }

    public var isStretchy: Bool { self == .widehat || self == .widetilde }

    public init?(command: String) {
        switch command {
        case "hat": self = .hat
        case "check": self = .check
        case "tilde": self = .tilde
        case "bar": self = .bar
        case "vec": self = .vec
        case "dot": self = .dot
        case "ddot": self = .ddot
        case "breve": self = .breve
        case "mathring": self = .mathring
        case "acute": self = .acute
        case "grave": self = .grave
        case "widehat": self = .widehat
        case "widetilde": self = .widetilde
        case "overline": self = .overline
        case "underline": self = .underline
        default: return nil
        }
    }
}

/// TeX atom classes drive inter-atom spacing (thin/medium/thick).
public enum MathAtomClass: Hashable, Sendable {
    case ordinary      // x, 1, α
    case largeOperator // ∑ ∫
    case binary        // + − ×
    case relation      // = ≤ →
    case opening       // ( [
    case closing       // ) ]
    case punctuation   // , ;
}

public enum MathSymbolStyle: Hashable, Sendable {
    case italic   // variables
    case roman    // digits, function names, operators
    case bold     // \mathbf — upright bold
}

/// Column alignment for a `.matrix` grid.
public enum MathMatrixStyle: Hashable, Sendable {
    case centered   // matrix / pmatrix / bmatrix …
    case cases      // left-aligned columns (a `cases` list)
    case aligned    // alternating right/left, meeting at the `&` (aligned/align)
    case substack   // tight centered stack at script size (\substack)
}
