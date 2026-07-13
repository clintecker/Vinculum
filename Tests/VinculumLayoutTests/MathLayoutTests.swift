import XCTest
import Foundation
@testable import VinculumLayout

/// Headless geometry tests: the layout engine runs with a DETERMINISTIC mock
/// measurer (no CoreText, no font), so these prove the layout is platform-free
/// and assert scene structure directly — the analog of MermaidKit's layout
/// linter. They run on Linux.
final class MathLayoutTests: XCTestCase {

    /// Every glyph is a `size`-square cell, so metrics are exact and testable.
    private let mock: MathTextMeasurer = { text, size, _ in
        GlyphMetrics(width: CGFloat(text.count) * size, ascent: size * 0.75, descent: size * 0.25,
                     inkAscent: size * 0.7, inkDescent: -size * 0.05)
    }
    private func engine(_ size: CGFloat = 10) -> MathLayoutEngine {
        MathLayoutEngine(measure: mock, baseSize: size)
    }

    func testSymbolSceneHasOneGlyphRun() {
        let scene = engine().layout(.symbol("x", .ordinary, style: .italic))
        XCTAssertEqual(scene.width, 10, accuracy: 0.001)       // one 10-wide cell
        let glyphs = scene.elements.filter { if case .glyphs = $0 { return true }; return false }
        XCTAssertEqual(glyphs.count, 1)
    }

    func testFractionEmitsARuleAndStacks() {
        let scene = engine().layout(MathParser.parse("\\frac{1}{2}"))
        let rules = scene.elements.filter { if case .rule = $0 { return true }; return false }
        XCTAssertEqual(rules.count, 1, "a fraction has exactly one rule (the bar)")
        // Numerator + rule + denominator is far taller than a single cell.
        XCTAssertGreaterThan(scene.height, 10 * 1.5)
    }

    func testRelationSpacingIsTeXThickSpace() {
        // With a mock where each glyph is `size` wide, x=y is 3 cells (30) plus
        // two TeX thick spaces (2 · 5/18 · size) around the relation.
        let s = engine().layout(MathParser.parse("x=y"))
        let expected = 30 + 2 * (5.0 / 18.0) * 10
        XCTAssertEqual(s.width, expected, accuracy: 0.001)
    }

    func testColorSubtreeCarriesResolvedSRGB() {
        let s = engine().layout(MathParser.parse("\\color{red}{x}"))
        guard case let .glyphs(_, _, _, _, color) = s.elements.first else {
            return XCTFail("expected a glyph run")
        }
        XCTAssertEqual(color, MathColor.resolve("red"))
    }

    func testIntegralKeepsSideScriptsButSumStacksInDisplay() {
        // In display, ∑ stacks its limits (taller than wide) while ∫ keeps them
        // to the side (wider, shorter) — TeX's \limits vs \nolimits defaults.
        let sum = engine().layout(MathParser.parse("\\sum_{i=1}^{n}"), display: true)
        let int = engine().layout(MathParser.parse("\\int_{0}^{1}"), display: true)
        XCTAssertGreaterThan(sum.height, sum.width, "∑ stacks its limits")
        XCTAssertGreaterThan(int.width, int.height, "∫ keeps side scripts")
    }

    func testNamedOperatorLimitStacksInDisplay() {
        // \lim_{x} stacks the limit underneath in display (it's a function name,
        // which used to miss the limits path).
        let e = engine()
        let stacked = e.layout(MathParser.parse("\\lim_{x}"), display: true)
        let inline  = e.layout(MathParser.parse("\\lim_{x}"), display: false)
        XCTAssertGreaterThan(stacked.height, inline.height, "the limit moves under the operator")
    }

    func testRadicalEmitsAStroke() {
        let s = engine().layout(MathParser.parse("\\sqrt{2}"))
        let strokes = s.elements.filter { if case .stroke = $0 { return true }; return false }
        XCTAssertEqual(strokes.count, 1, "the radical sign is one stroked path")
    }

    func testLayoutIsDeterministic() {
        let a = engine().layout(MathParser.parse("\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}"))
        let b = engine().layout(MathParser.parse("\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}"))
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        XCTAssertEqual(a.elements.count, b.elements.count)
    }
}
