#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics

/// The bundled OpenType math font (Latin Modern Math) plus the metrics from
/// its MATH table. This is what gives Vinculum genuine LaTeX quality — the
/// Computer-Modern glyph shapes AND the typesetting constants (axis height,
/// rule thickness, script scales, shifts) that a math font is required to
/// carry. Falls back to the system font if the resource can't be loaded, so
/// rendering degrades rather than fails.
enum MathFont {

    /// The loaded CGFont for the bundled math font, or nil if unavailable.
    static let cgFont: CGFont? = {
        guard let url = Bundle.module.url(forResource: "latinmodern-math", withExtension: "otf"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return nil }
        return font
    }()

    static var isAvailable: Bool { cgFont != nil }

    /// A CTFont for the math font at `size`, or nil (caller falls back).
    static func ctFont(size: CGFloat) -> CTFont? {
        guard let cgFont else { return nil }
        return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
    }

    /// MATH-table constants, as em fractions (the raw values are in the
    /// font's 1000-unit em). These are Latin Modern Math's authoritative
    /// numbers — the ones the engine previously hand-approximated.
    enum Constants {
        static let axisHeight: CGFloat = 0.250
        static let fractionRuleThickness: CGFloat = 0.040
        static let fractionNumeratorShiftUp: CGFloat = 0.394
        static let fractionDenominatorShiftDown: CGFloat = 0.345
        static let fractionNumeratorDisplayStyleShiftUp: CGFloat = 0.677
        static let fractionDenominatorDisplayStyleShiftDown: CGFloat = 0.686
        static let scriptPercentScaleDown: CGFloat = 0.70
        static let scriptScriptPercentScaleDown: CGFloat = 0.50
        static let superscriptShiftUp: CGFloat = 0.363
        static let subscriptShiftDown: CGFloat = 0.247
        static let radicalRuleThickness: CGFloat = 0.040
        static let radicalVerticalGap: CGFloat = 0.148
        static let overbarVerticalGap: CGFloat = 0.120
        static let overbarRuleThickness: CGFloat = 0.040
        static let underbarVerticalGap: CGFloat = 0.120
        static let accentBaseHeight: CGFloat = 0.450
        static let stackGapMin: CGFloat = 0.150
        static let upperLimitBaselineRiseMin: CGFloat = 0.111
        static let lowerLimitBaselineDropMin: CGFloat = 0.600
        static let spaceAfterScript: CGFloat = 0.041
    }
}
#endif
