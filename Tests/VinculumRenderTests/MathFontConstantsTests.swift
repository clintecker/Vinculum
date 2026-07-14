#if canImport(AppKit) || canImport(UIKit)
import XCTest
@testable import VinculumRender
import VinculumLayout

final class MathFontConstantsTests: XCTestCase {

    /// The live CGFont path (bundle → CGFont → raw MATH bytes → parser) must
    /// produce exactly the `.latinModern` preset, which is itself pinned to
    /// the committed fixture bytes and fontTools ground truth. Three-way
    /// agreement: font ↔ fixture ↔ preset.
    func testLiveFontConstantsMatchPreset() {
        XCTAssertTrue(MathFont.isAvailable)
        XCTAssertEqual(MathFont.constants, .latinModern)
    }
}
#endif
