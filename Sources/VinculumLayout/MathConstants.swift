import Foundation

/// Typesetting constants from the math font's OpenType MATH table, as em
/// fractions (the raw values are in the font's 1000-unit em). These are Latin
/// Modern Math's authoritative numbers — the metrics TeX would read from the
/// font. Layout lives in the platform-free module, so the constants live here
/// (pure data) rather than beside the font object in the renderer.
public enum MathConstants {
    public static let axisHeight: CGFloat = 0.250
    /// TeX's ξ8 `default_rule_thickness` — the one rule weight the extension
    /// font hands out for bars that have no dedicated OpenType constant
    /// (arrow shafts, `\boxed` frames). Fraction/radical/overbar carry their
    /// own MATH-table values below; all four happen to be 0.040 in LM Math.
    public static let defaultRuleThickness: CGFloat = 0.040
    public static let fractionRuleThickness: CGFloat = 0.040
    public static let fractionNumeratorShiftUp: CGFloat = 0.394
    public static let fractionDenominatorShiftDown: CGFloat = 0.345
    public static let scriptPercentScaleDown: CGFloat = 0.70
    public static let scriptScriptPercentScaleDown: CGFloat = 0.50
    public static let superscriptShiftUp: CGFloat = 0.363
    public static let subscriptShiftDown: CGFloat = 0.247
    public static let radicalRuleThickness: CGFloat = 0.040
    public static let radicalVerticalGap: CGFloat = 0.148
    public static let overbarVerticalGap: CGFloat = 0.120
    public static let overbarRuleThickness: CGFloat = 0.040
    public static let underbarVerticalGap: CGFloat = 0.120
    public static let accentBaseHeight: CGFloat = 0.450
    public static let stackGapMin: CGFloat = 0.150
    public static let upperLimitBaselineRiseMin: CGFloat = 0.111
    public static let lowerLimitBaselineDropMin: CGFloat = 0.600
    public static let spaceAfterScript: CGFloat = 0.041
}
