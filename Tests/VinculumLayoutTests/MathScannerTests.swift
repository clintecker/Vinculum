import XCTest
@testable import VinculumLayout

/// Delimiter scanning: `$…$` / `$$…$$` / `\(…\)` / `\[…\]` segmentation.
final class MathScannerTests: XCTestCase {

    func testInlineMathEndingInACommandCloses() {
        // Regression: the escape-skip didn't count the escaped char as ink,
        // so the closing `$` after `\R` looked whitespace-preceded and the
        // segment never closed.
        let segments = MathScanner.scan(#"use $x \in \R$ here"#)
        XCTAssertEqual(segments, [
            .text("use "), .inlineMath(#"x \in \R"#), .text(" here"),
        ])
    }

    func testBasicSegmentation() {
        XCTAssertEqual(MathScanner.scan(#"a $x$ b $$y$$ c \(z\) d \[w\] e"#), [
            .text("a "), .inlineMath("x"),
            .text(" b "), .displayMath("y"),
            .text(" c "), .inlineMath("z"),
            .text(" d "), .displayMath("w"),
            .text(" e"),
        ])
    }

    func testEscapedDollarAndPrices() {
        XCTAssertEqual(MathScanner.scan(#"costs \$5 or $10"#),
                       [.text(#"costs \$5 or $10"#)],
                       "escaped dollars and price-like text stay prose")
    }
}
