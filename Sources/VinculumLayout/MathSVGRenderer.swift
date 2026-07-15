import Foundation

/// Renders a `MathScene` to SVG — the platform-free renderer that makes
/// server-side math real: `VinculumLayout` already lays out on Linux; this
/// turns those scenes into markup any browser draws.
///
/// ```swift
/// let engine = MathLayoutEngine(measure: myMeasurer, baseSize: 16)
/// let scene = engine.layout(MathParser.parse latex), display: true)
/// let svg = MathSVGRenderer.svg(for: scene,
///                               embeddedFont: latinModernOTFBytes)
/// ```
///
/// Glyph runs become `<text>` (baseline-exact — SVG's alphabetic baseline
/// matches the scene's), rules become `<rect>`, stroked paths become
/// `<path>`. Pass the math font's OTF bytes via `embeddedFont` to make the
/// SVG fully self-contained (`@font-face` with a data URI); otherwise the
/// `fontFamily` must be available wherever the SVG is viewed.
///
/// Designed for HEADLESS scenes (engines without delimiter/assembly
/// providers, which is the Linux default): those contain no font-specific
/// `.glyph(id:)` elements. If a scene does carry them, they are skipped
/// with an XML comment — lay out headless for SVG, or draw glyph-ID scenes
/// with `MathSceneRenderer` on Apple platforms.
public enum MathSVGRenderer {

    /// SVG markup for `scene`. `ink` is any CSS color; `\color` overrides
    /// inside the scene take precedence per element.
    public static func svg(for scene: MathScene,
                           fontFamily: String = "Latin Modern Math",
                           ink: String = "#000000",
                           embeddedFont: Data? = nil,
                           padding: CGFloat = 2) -> String {
        let width = scene.width + padding * 2
        let height = scene.ascent + scene.descent + padding * 2
        // Scene coordinates are y-up with the origin on the baseline; SVG is
        // y-down from the top-left. The baseline lands at:
        let baseline = padding + scene.ascent
        func sx(_ x: CGFloat) -> String { fmt(padding + x) }
        func sy(_ y: CGFloat) -> String { fmt(baseline - y) }

        var out = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(fmt(width)) \(fmt(height))" \
        width="\(fmt(width))" height="\(fmt(height))" role="img">
        """
        if let embeddedFont {
            let b64 = embeddedFont.base64EncodedString()
            out += """

            <defs><style>@font-face { font-family: "\(fontFamily)"; \
            src: url(data:font/otf;base64,\(b64)) format("opentype"); }</style></defs>
            """
        }

        for element in scene.elements {
            switch element {
            case let .glyphs(text, size, mono, origin, color):
                let family = mono ? "ui-monospace, Menlo, monospace" : "\(escape(fontFamily))"
                out += """

                <text x="\(sx(origin.x))" y="\(sy(origin.y))" \
                font-family='\(family)' font-size="\(fmt(size))" \
                fill="\(fill(color, ink))">\(escape(text))</text>
                """

            case let .rule(rect, color):
                out += """

                <rect x="\(sx(rect.origin.x))" y="\(sy(rect.origin.y + rect.size.height))" \
                width="\(fmt(rect.size.width))" height="\(fmt(rect.size.height))" \
                fill="\(fill(color, ink))"/>
                """

            case let .stroke(path, width, cap, join, color):
                var d = ""
                for op in path {
                    switch op {
                    case .move(let p): d += "M \(sx(p.x)) \(sy(p.y)) "
                    case .line(let p): d += "L \(sx(p.x)) \(sy(p.y)) "
                    case let .quad(to, control):
                        d += "Q \(sx(control.x)) \(sy(control.y)) \(sx(to.x)) \(sy(to.y)) "
                    case .close: d += "Z "
                    }
                }
                out += """

                <path d="\(d.trimmingCharacters(in: .whitespaces))" fill="none" \
                stroke="\(fill(color, ink))" stroke-width="\(fmt(width))" \
                stroke-linecap="\(capName(cap))" stroke-linejoin="\(joinName(join))"/>
                """

            case .glyph:
                // Font-specific variant glyph ID — unrenderable without the
                // exact font's glyph table. Headless scenes never contain
                // these; see the type documentation.
                out += "\n<!-- skipped font-specific glyph element; lay out headless for SVG -->"

            case .region:
                break   // hit-test metadata, not ink
            }
        }
        out += "\n</svg>\n"
        return out
    }

    // MARK: - Helpers

    private static func fill(_ color: MathColor?, _ ink: String) -> String {
        guard let c = color else { return ink }
        func h(_ v: CGFloat) -> String { String(format: "%02x", Int((max(0, min(1, v)) * 255).rounded())) }
        return "#\(h(c.red))\(h(c.green))\(h(c.blue))"
    }

    private static func fmt(_ v: CGFloat) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func capName(_ c: StrokeCap) -> String {
        switch c { case .butt: return "butt"; case .round: return "round"; case .square: return "square" }
    }

    private static func joinName(_ j: StrokeJoin) -> String {
        switch j { case .miter: return "miter"; case .round: return "round"; case .bevel: return "bevel" }
    }
}
