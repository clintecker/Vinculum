import Foundation

// Vinculum's device-independent scene — the math analog of TeX's DVI: layout
// produces a platform-free description of WHAT to draw, and a renderer decides
// HOW. Everything here uses only Foundation geometry types (CGPoint/CGRect/
// CGFloat), which are available on every platform including Linux, so the
// whole layout stage is portable and headless-testable.

/// A platform-free sRGB color. `\color{name|#hex}` resolves to this during
/// layout; a `nil` color on a scene element means "use the theme ink", which
/// the renderer supplies.
public struct MathColor: Hashable, Sendable {
    public var red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// Resolves a `\color` argument: a "#rrggbb" hex or a named palette color.
    public static func resolve(_ name: String) -> MathColor? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        if key.hasPrefix("#") { return hex(key) }
        switch key {
        case "red": return MathColor(red: 1, green: 0.23, blue: 0.19)
        case "blue": return MathColor(red: 0, green: 0.48, blue: 1)
        case "green": return MathColor(red: 0.20, green: 0.78, blue: 0.35)
        case "orange": return MathColor(red: 1, green: 0.58, blue: 0)
        case "purple": return MathColor(red: 0.69, green: 0.32, blue: 0.87)
        case "teal": return MathColor(red: 0.19, green: 0.69, blue: 0.78)
        case "yellow": return MathColor(red: 1, green: 0.8, blue: 0)
        case "pink", "magenta": return MathColor(red: 1, green: 0.18, blue: 0.33)
        case "brown": return MathColor(red: 0.64, green: 0.52, blue: 0.37)
        case "gray", "grey": return MathColor(red: 0.56, green: 0.56, blue: 0.58)
        case "cyan": return MathColor(red: 0, green: 0.68, blue: 0.94)
        case "black": return MathColor(red: 0, green: 0, blue: 0)
        case "white": return MathColor(red: 1, green: 1, blue: 1)
        default: return nil
        }
    }

    private static func hex(_ hex: String) -> MathColor? {
        var v = hex; v.removeFirst()
        guard v.count == 6, let n = UInt32(v, radix: 16) else { return nil }
        return MathColor(red: CGFloat((n >> 16) & 0xFF) / 255,
                         green: CGFloat((n >> 8) & 0xFF) / 255,
                         blue: CGFloat(n & 0xFF) / 255)
    }
}

/// The typographic metrics of a laid-out glyph run, returned by the injected
/// measurer. Ink extents (the actual painted bounds) drive accent placement,
/// where the typographic box is too loose.
public struct GlyphMetrics: Sendable {
    public var width: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    /// Top of the actual ink above the baseline (≤ ascent).
    public var inkAscent: CGFloat
    /// Bottom of the actual ink relative to the baseline (usually ≥ -descent).
    public var inkDescent: CGFloat

    public init(width: CGFloat, ascent: CGFloat, descent: CGFloat,
                inkAscent: CGFloat, inkDescent: CGFloat) {
        self.width = width; self.ascent = ascent; self.descent = descent
        self.inkAscent = inkAscent; self.inkDescent = inkDescent
    }
}

/// Measures a glyph run at `size`. `mono` selects the monospace fallback used
/// for unsupported source; every other run is the math font. Style (italic/
/// bold) is already baked into the glyphs by codepoint remapping, so the
/// measurer needs nothing more. Injected by the host so layout is portable.
public typealias MathTextMeasurer = @Sendable (_ text: String, _ size: CGFloat, _ mono: Bool) -> GlyphMetrics

/// A segment of a stroked path, in scene coordinates (y-up).
public enum PathOp: Sendable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(to: CGPoint, control: CGPoint)
    case close
}

/// Platform-free stroke styling (CoreGraphics' CGLineCap/Join aren't on all
/// platforms, so the scene uses its own).
public enum StrokeCap: Sendable { case butt, round, square }
public enum StrokeJoin: Sendable { case miter, round, bevel }

/// One positioned drawing primitive. Coordinates are y-up with the origin at
/// the scene/box baseline. A `nil` color means the renderer's theme ink.
public enum MathElement: Sendable {
    /// A run of glyphs with its baseline origin at `origin`.
    case glyphs(text: String, size: CGFloat, mono: Bool, origin: CGPoint, color: MathColor?)
    /// A filled rectangle — fraction bars, overline/underline, boxed sides.
    case rule(CGRect, color: MathColor?)
    /// A stroked path — radical signs, braces, arrows, box borders.
    case stroke(path: [PathOp], width: CGFloat, cap: StrokeCap, join: StrokeJoin, color: MathColor?)

    /// The same element translated by `d` (used to place a sub-box).
    func translated(by d: CGPoint) -> MathElement {
        switch self {
        case let .glyphs(t, s, m, o, c):
            return .glyphs(text: t, size: s, mono: m,
                           origin: CGPoint(x: o.x + d.x, y: o.y + d.y), color: c)
        case let .rule(r, c):
            return .rule(CGRect(origin: CGPoint(x: r.origin.x + d.x, y: r.origin.y + d.y),
                                size: r.size), color: c)
        case let .stroke(p, w, cap, join, c):
            return .stroke(path: p.map { op in
                switch op {
                case .move(let pt): return .move(CGPoint(x: pt.x + d.x, y: pt.y + d.y))
                case .line(let pt): return .line(CGPoint(x: pt.x + d.x, y: pt.y + d.y))
                case let .quad(to, ctl): return .quad(to: CGPoint(x: to.x + d.x, y: to.y + d.y),
                                                      control: CGPoint(x: ctl.x + d.x, y: ctl.y + d.y))
                case .close: return .close
                }
            }, width: w, cap: cap, join: join, color: c)
        }
    }
}

/// A fully laid-out expression: overall metrics plus its positioned
/// primitives. This is Vinculum's device-independent output; `MathRenderer`
/// (VinculumRender) turns it into pixels/PDF, but the geometry lives here.
public struct MathScene: Sendable {
    public var width: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var elements: [MathElement]

    public var height: CGFloat { ascent + descent }

    public init(width: CGFloat, ascent: CGFloat, descent: CGFloat, elements: [MathElement]) {
        self.width = width; self.ascent = ascent; self.descent = descent; self.elements = elements
    }
}
