import XCTest
@testable import VinculumLayout

/// 1.0 hardening: the whole pipeline — parse → diagnostics → layout →
/// serialize → speech — must survive arbitrary garbage. Parse is total by
/// design (unknown input degrades to `.unsupported`, never throws, never
/// crashes); this proves it under deterministic fuzz (fixed-seed LCG, so
/// failures reproduce).
final class MathFuzzTests: XCTestCase {

    private let mock: MathTextMeasurer = { text, size, _ in
        GlyphMetrics(width: CGFloat(text.count) * size, ascent: size * 0.75, descent: size * 0.25,
                     inkAscent: size * 0.7, inkDescent: -size * 0.05)
    }

    private struct LCG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 33
        }
        mutating func below(_ n: Int) -> Int { Int(next()) % max(1, n) }
    }

    private func exercise(_ latex: String, engine: MathLayoutEngine) {
        let node = MathParser.parse(latex)
        _ = MathParser.isFullySupported(node)
        _ = MathParser.unsupportedCommands(in: node)
        _ = MathParser.diagnostics(for: latex)
        _ = node.toLaTeX()
        _ = MathSpeech.describe(node)
        let scene = engine.layout(node, display: true)
        XCTAssertTrue(scene.width.isFinite && scene.ascent.isFinite && scene.descent.isFinite,
                      "non-finite geometry for: \(latex)")
    }

    func testGrammarFuzzNeverCrashes() {
        let atoms = [
            "\\frac", "{", "}", "^", "_", "\\left(", "\\right)", "\\right", "\\left",
            "x", "1", "+", "=", "\\sum", "\\int", "\\begin{pmatrix}", "\\end{pmatrix}",
            "\\begin{cases}", "\\end{aligned}", "&", "\\\\", "\\sqrt", "[", "]",
            "\\alpha", "\\hat", "\\text{a b}", "\\color{red}", "\\middle|", "\\big",
            "\\newcommand", "\\def", "#1", "%", "$", "\\", "√", "∑", "😀", "\u{0000}",
            "\\operatorname*", "\\genfrac", "\\scriptstyle", "\\not", "'", "\\hline",
        ]
        var rng = LCG(state: 0x5EED_5EED)
        let engine = MathLayoutEngine(measure: mock, baseSize: 10)
        for _ in 0..<2000 {
            var s = ""
            for _ in 0..<rng.below(40) { s += atoms[rng.below(atoms.count)] }
            exercise(s, engine: engine)
        }
    }

    func testMutationFuzzNeverCrashes() {
        // Real expressions, randomly sliced and spliced — half-valid input is
        // the live-editor hot path (every keystroke is a truncated formula).
        let seeds = [
            #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#,
            #"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#,
            #"\left\langle u, \middle| v \right\rangle + \sum_{i=1}^{n} x_i"#,
            #"\cfrac{1}{1 + \cfrac{1}{x}} + \genfrac{[}{]}{0pt}{2}{a}{b}"#,
        ]
        var rng = LCG(state: 0xBADC_0FFE)
        let engine = MathLayoutEngine(measure: mock, baseSize: 10)
        for _ in 0..<2000 {
            let a = Array(seeds[rng.below(seeds.count)])
            let b = Array(seeds[rng.below(seeds.count)])
            let cut = rng.below(a.count)
            let paste = rng.below(b.count)
            var s = String(a.prefix(cut)) + String(b.suffix(from: b.index(b.startIndex, offsetBy: paste)))
            if rng.below(4) == 0, !s.isEmpty {
                s.remove(at: s.index(s.startIndex, offsetBy: rng.below(s.count)))
            }
            exercise(s, engine: engine)
        }
    }

    func testAdversarialDepthDegradesGracefully() {
        let engine = MathLayoutEngine(measure: mock, baseSize: 10)
        exercise(String(repeating: "{", count: 5_000), engine: engine)
        exercise(String(repeating: "\\frac{", count: 2_000), engine: engine)
        exercise(String(repeating: "\\begin{pmatrix}", count: 1_000), engine: engine)
        exercise(String(repeating: "x^", count: 3_000), engine: engine)
    }
}
