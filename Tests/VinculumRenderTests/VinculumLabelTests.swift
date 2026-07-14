#if canImport(AppKit)
import XCTest
import AppKit
@testable import VinculumRender
import VinculumLayout

@MainActor
final class VinculumLabelTests: XCTestCase {

    func testLabelRendersAndSizes() {
        let label = VinculumLabel(frame: .zero)
        label.latex = #"x^2 + y^2 = z^2"#
        XCTAssertTrue(label.isRendered)
        XCTAssertGreaterThan(label.intrinsicContentSize.width, 10)
        XCTAssertGreaterThan(label.intrinsicContentSize.height, 5)
    }

    func testInsetsGrowIntrinsicSize() {
        let label = VinculumLabel(frame: .zero)
        label.latex = "x"
        let bare = label.intrinsicContentSize
        label.contentInsets = .init(top: 4, left: 10, bottom: 4, right: 20)
        XCTAssertEqual(label.intrinsicContentSize.width, bare.width + 30, accuracy: 0.001)
        XCTAssertEqual(label.intrinsicContentSize.height, bare.height + 8, accuracy: 0.001)
    }

    func testUnsupportedIsSilentByDefault() {
        let label = VinculumLabel(frame: .zero)
        label.latex = #"\notacommand{x}"#
        XCTAssertFalse(label.isRendered, "unsupported input must not half-render")
        XCTAssertEqual(label.intrinsicContentSize, .zero,
                       "silent by default — the host supplies the fallback")
    }

    func testInlineErrorIsOptIn() {
        let label = VinculumLabel(frame: .zero)
        label.displayErrorInline = true
        label.latex = #"\notacommand{x}"#
        XCTAssertFalse(label.isRendered)
        XCTAssertGreaterThan(label.intrinsicContentSize.width, 0,
                             "opt-in inline error shows the source")
    }

    func testFontSelectionChangesRender() {
        let lm = VinculumLabel(frame: .zero)
        lm.latex = #"\sum_{i=1}^n i"#
        let stix = VinculumLabel(frame: .zero)
        stix.font = .stixTwo
        stix.latex = #"\sum_{i=1}^n i"#
        XCTAssertTrue(lm.isRendered && stix.isRendered)
        XCTAssertNotEqual(lm.intrinsicContentSize, stix.intrinsicContentSize,
                          "different fonts produce different geometry")
    }
}
#endif
