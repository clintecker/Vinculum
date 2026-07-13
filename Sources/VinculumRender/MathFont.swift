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
    /// A CGFont is immutable and safe to read from any thread; the compiler
    /// can't prove CGFont Sendable, so we vouch for it.
    nonisolated(unsafe) static let cgFont: CGFont? = {
        guard let url = Bundle.module.url(forResource: "latinmodern-math", withExtension: "otf"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return nil }
        return font
    }()

    static var isAvailable: Bool { cgFont != nil }

    // A tiny size→CTFont memo. Both measurement and drawing ask for the math
    // font at a handful of sizes (base, script, scriptscript, display) over and
    // over; `CTFontCreateWithGraphicsFont` isn't free, so cache it. Guarded by a
    // lock (the measurer runs off-main); the value set is naturally small.
    nonisolated(unsafe) private static var ctFontCache: [CGFloat: CTFont] = [:]
    private static let ctFontLock = NSLock()

    /// A CTFont for the math font at `size`, or nil (caller falls back).
    static func ctFont(size: CGFloat) -> CTFont? {
        guard let cgFont else { return nil }
        ctFontLock.lock(); defer { ctFontLock.unlock() }
        if let cached = ctFontCache[size] { return cached }
        let font = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        ctFontCache[size] = font
        return font
    }
}
// The MATH-table constants moved to VinculumLayout's `MathConstants` (they're
// pure numbers the platform-free layout stage needs).
#endif
