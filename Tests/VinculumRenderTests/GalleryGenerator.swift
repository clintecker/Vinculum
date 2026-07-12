#if canImport(AppKit)
import XCTest
import AppKit
import CoreText
import CoreGraphics
@testable import VinculumRender
import VinculumLayout

/// On-demand visual coverage gallery: renders labeled posters (LaTeX source
/// beside its native Vinculum render). Writes PNGs to $VINCULUM_GALLERY_DIR;
/// skipped when that env var is unset, so it never runs in normal CI.
final class GalleryGenerator: XCTestCase {

    func testGenerateGallery() throws {
        guard let dir = ProcessInfo.processInfo.environment["VINCULUM_GALLERY_DIR"] else {
            throw XCTSkip("set VINCULUM_GALLERY_DIR to generate the gallery")
        }
        let out = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        // Pin Aqua so the .light ink resolves to black consistently.
        NSApp?.appearance = NSAppearance(named: .aqua)

        try poster(to: out.appendingPathComponent("01-core.png"), title: "Fractions · roots · scripts · operators", sections: [
            ("Fractions, roots, scripts", [
                #"\frac{a}{b}"#, #"\dfrac{\partial^2 u}{\partial x^2}"#, #"\sqrt{2}"#,
                #"\sqrt[3]{x^2 + y^2}"#, #"x^{2^{n}}"#, #"a_{i,j}^{(k)}"#, #"\cfrac{1}{1+\cfrac{1}{x}}"#,
            ]),
            ("Big operators with limits", [
                #"\sum_{i=1}^{n} i^2 = \frac{n(n+1)(2n+1)}{6}"#, #"\prod_{k=1}^{n} k = n!"#,
                #"\int_{0}^{\infty} e^{-x^2}\, dx = \frac{\sqrt{\pi}}{2}"#,
                #"\lim_{x \to 0} \frac{\sin x}{x} = 1"#, #"\bigcup_{i \in I} A_i"#,
            ]),
        ])

        try poster(to: out.appendingPathComponent("02-structures.png"), title: "Delimiters · matrices · cases · aligned", sections: [
            ("Auto-sized delimiters", [
                #"\left( \frac{a}{b} \right)"#, #"\left[ \sum_i x_i \right]"#,
                #"\left\langle u, v \right\rangle"#, #"\left\lVert x \right\rVert"#,
                #"\left\{ x \in \mathbb{R} : x > 0 \right\}"#,
            ]),
            ("Matrices & environments", [
                #"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#,
                #"\begin{vmatrix} a & b \\ c & d \end{vmatrix} = ad - bc"#,
                #"\begin{cases} x^2 & x \ge 0 \\ -x & x < 0 \end{cases}"#,
                #"\begin{aligned} a &= b + c \\ &= d + e \end{aligned}"#,
            ]),
        ])

        try poster(to: out.appendingPathComponent("03-notation.png"), title: "Accents · binomials · braces · arrows · alphabets · color", sections: [
            ("Accents & decorations", [
                #"\hat{x} \quad \vec{v} \quad \bar{z} \quad \dot{x} \quad \ddot{y}"#,
                #"\widehat{ABC} \quad \overline{AB} \quad \underline{xy}"#, #"\boxed{E = mc^2}"#,
            ]),
            ("Binomials, braces, arrows", [
                #"\binom{n}{k} = \frac{n!}{k!(n-k)!}"#,
                #"\overbrace{a + b + c}^{\text{sum}} \quad \underbrace{1 + \cdots + n}_{n\text{ terms}}"#,
                #"A \xrightarrow{f} B \xrightarrow[g]{} C"#, #"\sum_{\substack{i < n \\ i \text{ odd}}} i"#,
            ]),
            ("Alphabets & color", [
                #"\mathbb{R} \subset \mathbb{C}, \quad \mathcal{L}(f), \quad \mathfrak{g}, \quad \mathsf{AB}\, \mathtt{cd}"#,
                #"\color{#cc2222}{x} + \color{#2244cc}{y} = \color{#00aa88}{z}"#,
            ]),
        ])

        try poster(to: out.appendingPathComponent("04-equations.png"), title: "Real-world equations", sections: [
            ("", [
                #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#,
                #"e^{i\pi} + 1 = 0"#,
                #"i\hbar \frac{\partial}{\partial t} \Psi = \hat{H} \Psi"#,
                #"P(A \mid B) = \frac{P(B \mid A)\, P(A)}{P(B)}"#,
                #"\nabla \times \vec{B} = \mu_0 \vec{J} + \mu_0 \epsilon_0 \frac{\partial \vec{E}}{\partial t}"#,
                #"\zeta(s) = \sum_{n=1}^{\infty} \frac{1}{n^s} = \prod_{p} \frac{1}{1 - p^{-s}}"#,
            ]),
        ])

        try poster(to: out.appendingPathComponent("06-symbols.png"), title: "Standalone delimiters & symbol coverage", sections: [
            ("Delimiters (now work outside \\left…\\right)", [
                #"\langle x, y \rangle \quad \lceil x \rceil \quad \lfloor x \rfloor \quad \lVert v \rVert"#,
                #"\uparrow \downarrow \Uparrow \Downarrow \quad A \hookrightarrow B \quad x \longrightarrow y"#,
            ]),
            ("Relations & operators", [
                #"a \preceq b \prec c \quad x \sqsubseteq y \quad p \models q \quad \Gamma \vdash \varphi"#,
                #"a \star b \quad u \boxplus v \quad x \odot y \quad P \iff Q \quad A \implies B"#,
                #"\top \quad \bot \quad \nmid \quad a \lesssim b \gtrsim c \quad \wp \quad \Im \quad \Re"#,
            ]),
        ])

        try poster(to: out.appendingPathComponent("05-macros.png"), title: "Document-scoped \\newcommand macros", sections: [
            ("Define once, use anywhere (expanded before typesetting)", [
                #"\newcommand{\abs}[1]{\left|#1\right|} \abs{x} + \abs{y} \ge \abs{x + y}"#,
                #"\newcommand{\R}{\mathbb{R}}\newcommand{\inner}[2]{\langle #1, #2 \rangle} \inner{u}{v} \in \R"#,
            ]),
        ])
    }

    // MARK: - Compositor

    private struct Row { let label: String; let scene: MathScene; let labelLine: CTLine?; let labelW: CGFloat; let labelAsc: CGFloat; let labelDesc: CGFloat }

    private func poster(to url: URL, title: String, sections: [(String, [String])]) throws {
        let engine = MathLayoutEngine(measure: CoreTextMeasurer.make(), baseSize: 22)
        let labelFont = CTFontCreateWithName("Menlo" as CFString, 12, nil)
        let headerFont = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 15, nil)
        let titleFont = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 20, nil)
        let gray = PlatformColor(white: 0.45, alpha: 1)
        let ink = PlatformColor.black
        let accent = PlatformColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1)

        func line(_ s: String, _ font: CTFont) -> (CTLine, CGFloat, CGFloat, CGFloat) {
            let attr = NSAttributedString(string: s, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorFromContextAttributeName as NSAttributedString.Key: true])
            let l = CTLineCreateWithAttributedString(attr)
            var a: CGFloat = 0, d: CGFloat = 0, lead: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(l, &a, &d, &lead))
            return (l, w, a, d)
        }

        // Pre-layout every row + section header.
        struct Section { let header: (CTLine, CGFloat, CGFloat, CGFloat)?; let rows: [Row] }
        var built: [Section] = []
        var labelColW: CGFloat = 0, boxColW: CGFloat = 0
        for (header, exprs) in sections {
            var rows: [Row] = []
            for latex in exprs {
                // Expand \newcommand macros the way a host (Quoin's
                // MarkdownConverter) does. collectDefinitions scans math
                // SEGMENTS, so wrap the raw latex as a $$…$$ block first.
                let table = MathMacros.collectDefinitions(from: "$$" + latex + "$$")
                let expanded = MathMacros.expand(latex, with: table)
                let scene = engine.layout(MathParser.parse(expanded), display: true)
                let (ll, lw, la, ld) = line(latex, labelFont)
                rows.append(Row(label: latex, scene: scene, labelLine: ll, labelW: lw, labelAsc: la, labelDesc: ld))
                labelColW = max(labelColW, lw)
                boxColW = max(boxColW, scene.width)
            }
            let h = header.isEmpty ? nil : line(header, headerFont)
            built.append(Section(header: h, rows: rows))
        }

        let margin: CGFloat = 28, gutter: CGFloat = 40, rowGap: CGFloat = 22, sectionGap: CGFloat = 26
        let (titleLine, titleW, titleAsc, titleDesc) = line(title, titleFont)
        let width = margin * 2 + max(labelColW + gutter + boxColW, titleW)

        // Total height.
        var height = margin + (titleAsc + titleDesc) + sectionGap
        for s in built {
            if let h = s.header { height += h.2 + h.3 + rowGap * 0.6 }
            for r in s.rows { height += max(r.scene.height, r.labelAsc + r.labelDesc) + rowGap }
            height += sectionGap
        }
        height += margin - rowGap

        // Bitmap at 2x.
        let scale: CGFloat = 2
        guard let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw XCTSkip("no context")
        }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(PlatformColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func draw(_ l: CTLine, x: CGFloat, baseline y: CGFloat, color: PlatformColor) {
            ctx.saveGState(); ctx.setFillColor(resolvedCGColor(color)); ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(l, ctx); ctx.restoreGState()
        }

        // Draw top-down (y-up coords: start near the top = height - margin).
        var y = height - margin - titleAsc
        draw(titleLine, x: margin, baseline: y, color: accent)
        y -= titleDesc + sectionGap

        let boxX = margin + labelColW + gutter
        for s in built {
            if let h = s.header {
                y -= h.2
                draw(h.0, x: margin, baseline: y, color: ink)
                y -= h.3 + rowGap * 0.6
            }
            for r in s.rows {
                let rowAsc = max(r.scene.ascent, r.labelAsc)
                let rowDesc = max(r.scene.descent, r.labelDesc)
                y -= rowAsc
                // Label right-aligned in its column.
                if let ll = r.labelLine {
                    draw(ll, x: margin + (labelColW - r.labelW), baseline: y, color: gray)
                }
                // Math left-aligned, baseline shared with the label.
                MathSceneRenderer.draw(r.scene, theme: .light, in: ctx, at: CGPoint(x: boxX, y: y))
                y -= rowDesc + rowGap
            }
            y -= sectionGap
        }

        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw XCTSkip("no image")
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
#endif
