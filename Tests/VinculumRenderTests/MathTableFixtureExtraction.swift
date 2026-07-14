#if canImport(AppKit) || canImport(UIKit)
import XCTest
@testable import VinculumRender

/// Regenerates the raw OpenType `MATH` table fixtures under
/// `Tests/fixtures/math-table/`, one `.bin` per bundled font.
///
/// The committed bytes let `VinculumLayoutTests` verify MATH-table *parsing*
/// headless on Linux — no CoreText, no display — the same way the golden
/// PNGs pin rendering. Regenerate (only when a bundled font changes) with:
///
///     VINCULUM_UPDATE_MATH_FIXTURES=1 swift test \
///       --filter MathTableFixtureExtraction
final class MathTableFixtureExtraction: XCTestCase {

    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/fixtures/math-table")
    }

    func testExtractMathTableFixtures() throws {
        guard ProcessInfo.processInfo.environment["VINCULUM_UPDATE_MATH_FIXTURES"] == "1" else {
            throw XCTSkip("Set VINCULUM_UPDATE_MATH_FIXTURES=1 to regenerate Tests/fixtures/math-table/.")
        }
        let cgFont = try XCTUnwrap(MathFont.cgFont, "bundled font failed to load")
        let table = try XCTUnwrap(cgFont.table(for: 0x4D41_5448 /* 'MATH' */),
                                  "bundled font has no MATH table")
        let data = table as Data
        XCTAssertGreaterThan(data.count, 4, "MATH table implausibly small")

        try FileManager.default.createDirectory(at: fixtureDirectory,
                                                withIntermediateDirectories: true)
        let destination = fixtureDirectory.appendingPathComponent("latinmodern-math.bin")
        try data.write(to: destination)
        print("Wrote \(data.count) bytes to \(destination.path)")
    }
}
#endif
