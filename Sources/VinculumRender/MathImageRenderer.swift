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

    private final class Entry {
        let image: PlatformImage
        let descent: CGFloat
        init(image: PlatformImage, descent: CGFloat) { self.image = image; self.descent = descent }
    }

    private static let cache = NSCache<NSString, Entry>()
    /// The shared CoreText measurer feeding the platform-free layout engine.
    private static let measurer: MathTextMeasurer = CoreTextMeasurer.make()

    /// An attachment string for the given LaTeX, or nil if unsupported.
    public static func attachmentString(
        latex: String,
        display: Bool,
        mathTheme: MathTheme,
        baseSize: CGFloat
    ) -> NSAttributedString? {
        let node = MathParser.parse(latex)
        guard MathParser.isFullySupported(node) else { return nil }

        let key = "\(display ? "D" : "I")|\(mathTheme.fingerprint)|\(baseSize)|\(latex)" as NSString
        let entry: Entry
        if let cached = cache.object(forKey: key) {
            entry = cached
        } else {
            let engine = MathLayoutEngine(measure: measurer, baseSize: display ? baseSize * 1.15 : baseSize)
            let scene = engine.layout(node, display: display)
            guard scene.width > 0, scene.height > 0 else { return nil }

            let padding: CGFloat = 2
            let size = CGSize(width: ceil(scene.width) + padding * 2,
                              height: ceil(scene.height) + padding * 2)
            let origin = CGPoint(x: padding, y: scene.descent + padding)

            #if canImport(AppKit)
            let appearance = NSAppearance(named: mathTheme.prefersDark ? .darkAqua : .aqua)
            let image = NSImage(size: size, flipped: false) { _ in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                let draw = { MathSceneRenderer.draw(scene, theme: mathTheme, in: context, at: origin) }
                if let appearance { appearance.performAsCurrentDrawingAppearance(draw) } else { draw() }
                return true
            }
            #else
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { rendererContext in
                let context = rendererContext.cgContext
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
                MathSceneRenderer.draw(scene, theme: mathTheme, in: context, at: origin)
            }
            #endif
            entry = Entry(image: image, descent: scene.descent + padding)
            cache.setObject(entry, forKey: key)
        }

        let attachment = NSTextAttachment()
        attachment.image = entry.image
        let imageSize = entry.image.size
        attachment.bounds = CGRect(x: 0, y: -entry.descent, width: imageSize.width, height: imageSize.height)
        return NSAttributedString(attachment: attachment)
    }
}
#endif
