#if canImport(AppKit)
import XCTest
import AppKit
import CoreText
@testable import VinculumRender
import VinculumLayout

/// Generates `07-fonts.png` — the same equations rendered in every bundled
/// math font, labeled — for the CI-published gallery. Run with:
///
///     VINCULUM_GALLERY_DIR=/tmp/vinculum-gallery \
///       swift test --filter FontShowcaseGenerator
@MainActor
final class FontShowcaseGenerator: XCTestCase {

    // Two lines per font: a real equation, then the glyphs where the faces
    // diverge most (italic bowls, Greek, display operators, blackboard).
    private static let samples = [
        #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \qquad \sum_{n=1}^{\infty} \frac{1}{n^s} = \prod_p \frac{1}{1-p^{-s}}"#,
        #"a\, g\, x\, y\, \alpha\, \gamma\, \delta\, \xi\, \partial \qquad \mathcal{L}\, \mathbb{R}\, \mathfrak{g} \qquad \int_0^\infty \oint_C"#,
    ]

    private static let fonts: [(MathFont, String, String)] = [
        (.latinModern, "Latin Modern Math", "the Computer Modern classic — Vinculum's default"),
        (.termes, "TeX Gyre Termes Math", "Times companion — for Times/serif body text"),
        (.pagella, "TeX Gyre Pagella Math", "Palatino companion — calligraphic warmth"),
        (.stixTwo, "STIX Two Math", "the scientific-publishing standard; ships cut-in kerning data"),
    ]

    func testGenerateFontShowcase() throws {
        guard let dir = ProcessInfo.processInfo.environment["VINCULUM_GALLERY_DIR"] else {
            throw XCTSkip("Set VINCULUM_GALLERY_DIR to generate the font showcase poster.")
        }
        let scale: CGFloat = 2
        let margin: CGFloat = 24, rowGap: CGFloat = 18, labelGap: CGFloat = 6

        func textLine(_ s: String, _ font: CTFont, _ color: NSColor) -> (CTLine, CGFloat, CGFloat) {
            let attr = NSAttributedString(string: s, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: color])
            let l = CTLineCreateWithAttributedString(attr)
            var a: CGFloat = 0, d: CGFloat = 0, lead: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(l, &a, &d, &lead))
            return (l, w, a + d)
        }

        let nameFont = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 15, nil)
        let blurbFont = CTFontCreateWithName("HelveticaNeue" as CFString, 12, nil)
        let titleFont = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 20, nil)

        // Render every font's sample first to size the canvas.
        struct FontRow {
            let name: (CTLine, CGFloat, CGFloat)
            let blurb: (CTLine, CGFloat, CGFloat)
            let images: [NSImage]
        }
        var rows: [FontRow] = []
        for (font, name, blurb) in Self.fonts {
            var images: [NSImage] = []
            for sample in Self.samples {
                let rendered = try XCTUnwrap(
                    MathImageRenderer.rendered(latex: sample, display: true,
                                               mathTheme: .light, baseSize: 22, font: font),
                    "showcase sample failed to render in \(name)")
                images.append(rendered.image)
            }
            rows.append(FontRow(name: textLine(name, nameFont, .black),
                                blurb: textLine("— " + blurb, blurbFont, NSColor(white: 0.42, alpha: 1)),
                                images: images))
        }
        let title = textLine("One engine, four fonts (plus any OTF with a MATH table)", titleFont, .black)

        var width = title.1 + margin * 2
        var height = margin + title.2 + rowGap
        let lineGap: CGFloat = 8
        for row in rows {
            let imgW = row.images.map(\.size.width).max() ?? 0
            let imgH = row.images.map(\.size.height).reduce(0, +)
                + lineGap * CGFloat(max(0, row.images.count - 1))
            width = max(width, margin * 2 + max(imgW, row.name.1 + 8 + row.blurb.1))
            height += row.name.2 + labelGap + imgH + rowGap
        }
        height += margin - rowGap

        let pxW = Int(ceil(width * scale)), pxH = Int(ceil(height * scale))
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = ns
        defer { NSGraphicsContext.current = nil }

        var y = height - margin - title.2
        ctx.textPosition = CGPoint(x: margin, y: y)
        CTLineDraw(title.0, ctx)
        y -= rowGap
        for row in rows {
            y -= row.name.2
            ctx.textPosition = CGPoint(x: margin, y: y)
            CTLineDraw(row.name.0, ctx)
            ctx.textPosition = CGPoint(x: margin + row.name.1 + 8, y: y)
            CTLineDraw(row.blurb.0, ctx)
            y -= labelGap
            for image in row.images {
                y -= image.size.height
                image.draw(in: CGRect(x: margin, y: y,
                                      width: image.size.width, height: image.size.height),
                           from: .zero, operation: .sourceOver, fraction: 1)
                y -= lineGap
            }
            y += lineGap
            y -= rowGap
        }

        let image = try XCTUnwrap(ctx.makeImage())
        let url = URL(fileURLWithPath: dir).appendingPathComponent("07-fonts.png")
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        print("Wrote \(url.path)")
    }
}
#endif
