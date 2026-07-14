import Foundation

/// TeX's four math styles (The TeXbook ch. 17, Appendix G). Cramped variants
/// are tracked separately (the engine's `cramped` flag), giving the full
/// eight-style lattice: D, D′, T, T′, S, S′, SS, SS′.
///
/// The style drives *decisions* (constant selection, spacing suppression,
/// limits placement); glyph *size* is threaded alongside it, descending by
/// `scriptSizeRatio` when the style descends.
public enum MathStyle: Int, Comparable, Sendable, Hashable {
    case display = 0
    case text = 1
    case script = 2
    case scriptScript = 3

    /// TeX's `sup_style`/`sub_style` size successor: D,T → S; S,SS → SS.
    public var scriptStyle: MathStyle { self <= .text ? .script : .scriptScript }

    /// TeX's `num_style`/`denom_style` successor: D → T, T → S, S,SS → SS.
    public var fractionStyle: MathStyle {
        switch self {
        case .display: return .text
        case .text: return .script
        case .script, .scriptScript: return .scriptScript
        }
    }

    public var isDisplay: Bool { self == .display }

    /// Script styles and smaller suppress medium/thick inter-atom spacing
    /// (TeX ch. 18's "\nonscript" column of the spacing chart).
    public var isScriptLevel: Bool { self >= .script }

    /// The factor the current glyph size shrinks by when descending into this
    /// style's `scriptStyle`. From text: `ScriptPercentScaleDown`. From
    /// script: the remaining ratio down to `ScriptScriptPercentScaleDown`
    /// (so a nested script lands at 50% of the base, TeX's floor — not
    /// 0.7 × 0.7 = 49% and shrinking forever). From scriptScript: 1.
    public func scriptSizeRatio(_ constants: MathFontConstants) -> CGFloat {
        switch self {
        case .display, .text:
            return constants.scriptPercentScaleDown
        case .script:
            guard constants.scriptPercentScaleDown > 0 else { return 1 }
            return constants.scriptScriptPercentScaleDown / constants.scriptPercentScaleDown
        case .scriptScript:
            return 1
        }
    }

    /// The glyph-size factor of this style relative to text size (TeX: text
    /// and display share the base size; script/scriptscript shrink by the
    /// font's percent-scale-down constants). Used when a `\scriptstyle`-like
    /// command *forces* a style, so the forced size lands where the style
    /// lattice would have put it.
    public func sizeFactor(_ constants: MathFontConstants) -> CGFloat {
        switch self {
        case .display, .text: return 1
        case .script: return constants.scriptPercentScaleDown
        case .scriptScript: return constants.scriptScriptPercentScaleDown
        }
    }

    public static func < (lhs: MathStyle, rhs: MathStyle) -> Bool { lhs.rawValue < rhs.rawValue }
}
