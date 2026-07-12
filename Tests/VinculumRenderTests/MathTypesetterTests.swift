#if canImport(AppKit) || canImport(UIKit)
import XCTest
import CoreGraphics
@testable import VinculumRender
import VinculumLayout

/// Font-independent invariants of the typesetter and the attachment API.
/// (The Quoin-side integration — how the block renderer tags `mathSource`
/// and falls back to a source card — is tested in Quoin, not here.)
final class MathTypesetterTests: XCTestCase {

    private let baseSize: CGFloat = 14

    private func typesetter() -> MathTypesetter { MathTypesetter(mathTheme: .light, baseSize: baseSize) }
    private func box(_ latex: String, display: Bool = false) -> MathTypesetter.MathBox {
        typesetter().layout(MathParser.parse(latex), display: display)
    }

    // MARK: - Support classification drives native vs. fallback

    func testSupportedMathProducesNonDegenerateAttachment() throws {
        for latex in ["E = mc^2", "\\frac{a}{b}", "x^2 + y^2", "\\sqrt{2}", "\\sum_{i=1}^{n} i"] {
            XCTAssertTrue(MathParser.isFullySupported(MathParser.parse(latex)), "\(latex) should be supported")
            let attachment = MathImageRenderer.attachmentString(
                latex: latex, display: false, mathTheme: .light, baseSize: baseSize
            )
            let string = try XCTUnwrap(attachment, "\(latex): expected a native attachment")
            XCTAssertEqual(string.length, 1, "\(latex): an attachment is one U+FFFC glyph")
            let value = string.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
            let bounds = try XCTUnwrap(value?.bounds, "\(latex): attachment has no bounds")
            XCTAssertGreaterThan(bounds.width, 0, "\(latex): degenerate width")
            XCTAssertGreaterThan(bounds.height, 0, "\(latex): degenerate height")
        }
    }

    func testUnsupportedMathReturnsNilSoRendererFallsBack() {
        // \unknownmacro parses to an `.unsupported` leaf → not fully supported
        // → the host keeps its styled source card instead of a broken glyph.
        let latex = "\\weirdcommand{x} + \\notreal"
        XCTAssertFalse(MathParser.isFullySupported(MathParser.parse(latex)))
        XCTAssertNil(MathImageRenderer.attachmentString(
            latex: latex, display: false, mathTheme: .light, baseSize: baseSize
        ), "unsupported LaTeX must return nil so the host keeps the fallback")
    }

    // MARK: - Font-independent MathBox structural invariants

    func testFractionStacksTallerThanNumerator() {
        let fraction = box("\\frac{1}{2}")
        let numeral = box("1")
        XCTAssertGreaterThan(fraction.width, 0)
        XCTAssertGreaterThan(fraction.height, numeral.height * 1.5,
            "a fraction stacks numerator over denominator, so it is far taller than one numeral")
    }

    /// TeX puts a *thick* (5/18 em) space on each side of a relation. The
    /// extra width is the only difference between `x=y` and the glyphs
    /// `xy` + `=` laid out without relation spacing, so the font glyph
    /// widths cancel and the surplus must be ≈ 2·(5/18)·size, on any font.
    func testRelationSpacingMatchesTeXThickSpace() {
        let withRelation = box("x=y").width
        let glyphs = box("xy").width + box("=").width
        let surplus = withRelation - glyphs
        let expected = 2 * (5.0 / 18.0) * baseSize
        XCTAssertEqual(surplus, expected, accuracy: 0.5,
            "relation should contribute two TeX thick spaces (\(expected)pt), got \(surplus)pt")
    }

    func testDisplayLimitsStackTallerThanInlineScripts() {
        let display = box("\\sum_{i=1}^{n} i", display: true)
        let inline = box("\\sum_{i=1}^{n} i", display: false)
        XCTAssertGreaterThan(display.height, inline.height,
            "display style stacks the operator's limits above and below, growing its height")
    }
}
#endif
