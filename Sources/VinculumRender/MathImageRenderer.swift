#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreGraphics
import VinculumLayout

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// The public entry point: turns LaTeX into a baseline-aligned text attachment,
/// orchestrating measure → layout → render. Results are cached by content +
/// theme + size. Returns nil when the LaTeX contains unsupported commands so a
/// host keeps its own fallback and a document never breaks.
public enum MathImageRenderer {

    // A cached result. A `nil` image is a NEGATIVE entry — LaTeX we already know
    // is unsupported or degenerate — so re-projecting it (every keystroke, in a
    // live editor) is a dictionary hit instead of a re-parse forever.
    private final class Entry {
        let image: PlatformImage?
        let descent: CGFloat
        let cost: Int
        init(image: PlatformImage?, descent: CGFloat, cost: Int) {
            self.image = image; self.descent = descent; self.cost = cost
        }
    }

    // NSCache is documented thread-safe; the compiler can't prove it Sendable.
    // Bounded by count and by pixel-byte cost so a long session can't grow the
    // bitmap cache without limit (matters most on iOS at 3×).
    nonisolated(unsafe) private static let cache: NSCache<NSString, Entry> = {
        let c = NSCache<NSString, Entry>()
        c.countLimit = 512
        c.totalCostLimit = 32 * 1024 * 1024
        return c
    }()
    /// The shared CoreText measurer feeding the platform-free layout engine.
    private static let measurer: MathTextMeasurer = CoreTextMeasurer.make()
    /// MATH-table delimiter size-variant provider (thins tall-fence strokes).
    private static let delimiterProvider: MathDelimiterProvider = CoreTextDelimiterProvider.make()

    /// An attachment string for the given LaTeX, or nil if unsupported.
    public static func attachmentString(
        latex: String,
        display: Bool,
        mathTheme: MathTheme,
        baseSize: CGFloat
    ) -> NSAttributedString? {
        // The key is fully determined by the arguments, so check the cache
        // BEFORE parsing — a hit (positive OR negative) costs no parse/layout.
        let key = "\(display ? "D" : "I")|\(mathTheme.fingerprint)|\(baseSize)|\(latex)" as NSString
        let entry: Entry
        if let cached = cache.object(forKey: key) {
            entry = cached
        } else {
            entry = buildEntry(latex: latex, display: display, mathTheme: mathTheme, baseSize: baseSize)
            cache.setObject(entry, forKey: key, cost: entry.cost)
        }

        guard let image = entry.image else { return nil }
        let attachment = NSTextAttachment()
        attachment.image = image
        let imageSize = image.size
        attachment.bounds = CGRect(x: 0, y: -entry.descent, width: imageSize.width, height: imageSize.height)
        return NSAttributedString(attachment: attachment)
    }

    /// Parses, lays out and rasterizes on a cache miss. Returns a negative
    /// entry (nil image) for unsupported/degenerate input so it's remembered.
    private static func buildEntry(latex: String, display: Bool,
                                   mathTheme: MathTheme, baseSize: CGFloat) -> Entry {
        let negative = Entry(image: nil, descent: 0, cost: 1)
        let node = MathParser.parse(latex)
        guard MathParser.isFullySupported(node) else { return negative }

        let engine = MathLayoutEngine(measure: measurer, baseSize: display ? baseSize * 1.15 : baseSize,
                                      delimiters: delimiterProvider)
        let scene = engine.layout(node, display: display)
        guard scene.width > 0, scene.height > 0 else { return negative }

        let padding: CGFloat = 2
        let size = CGSize(width: ceil(scene.width) + padding * 2,
                          height: ceil(scene.height) + padding * 2)
        let origin = CGPoint(x: padding, y: scene.descent + padding)
        // No explicit \color anywhere → a tintable template image, so selected
        // math inverts with the run and dark-mode adapts without a re-render.
        let isTemplate = !scene.hasExplicitColor

        #if canImport(AppKit)
        let appearance = NSAppearance(named: mathTheme.prefersDark ? .darkAqua : .aqua)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let draw = { MathSceneRenderer.draw(scene, theme: mathTheme, in: context, at: origin) }
            if let appearance { appearance.performAsCurrentDrawingAppearance(draw) } else { draw() }
            return true
        }
        image.isTemplate = isTemplate
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        var image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            // Pin the trait style so a dynamic UIColor ink resolves to the
            // variant matching the theme's canvas, not the ambient trait.
            let traits = UITraitCollection(userInterfaceStyle: mathTheme.prefersDark ? .dark : .light)
            traits.performAsCurrent {
                MathSceneRenderer.draw(scene, theme: mathTheme, in: context, at: origin)
            }
        }
        if isTemplate { image = image.withRenderingMode(.alwaysTemplate) }
        #endif

        let cost = Int(size.width * size.height * 4) // ~bytes/point²; proportional
        return Entry(image: image, descent: scene.descent + padding, cost: cost)
    }
}
#endif
