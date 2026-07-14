import Foundation

/// Superseded by `MathFontConstants` (Phase 1): the engine now carries an
/// instance of the constants — parsed from the live font's MATH table by
/// `MathTableParser`, or the `.latinModern` preset headless — instead of
/// reading this static transcription.
///
/// Kept only for source compatibility; three of these values were
/// mistranscriptions the parser oracle caught (`spaceAfterScript` 0.041 →
/// font 0.056; `radicalVerticalGap` 0.148 is the *display* value, text is
/// 0.050; `stackGapMin` 0.150 → font 0.120). The values below are unchanged
/// so existing callers see no silent shift; new code must use
/// `MathFontConstants`.
@available(*, deprecated, message: "Use MathFontConstants (font-parsed via MathTableParser, or .latinModern).")
public enum MathConstants {
    public static let axisHeight: CGFloat = 0.250
    public static let defaultRuleThickness: CGFloat = 0.040
    public static let fractionRuleThickness: CGFloat = 0.040
    public static let fractionNumeratorShiftUp: CGFloat = 0.394
    public static let fractionDenominatorShiftDown: CGFloat = 0.345
    public static let scriptPercentScaleDown: CGFloat = 0.70
    public static let scriptScriptPercentScaleDown: CGFloat = 0.50
    public static let superscriptShiftUp: CGFloat = 0.363
    public static let superscriptShiftUpCramped: CGFloat = 0.289
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
