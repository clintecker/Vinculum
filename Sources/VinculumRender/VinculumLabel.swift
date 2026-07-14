#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreGraphics
import VinculumLayout

#if canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
public typealias PlatformEdgeInsets = NSEdgeInsets
#else
import UIKit
public typealias PlatformView = UIView
public typealias PlatformEdgeInsets = UIEdgeInsets
#endif

/// The one-line adoption story: a view that renders LaTeX math.
///
/// ```swift
/// let label = VinculumLabel()
/// label.latex = #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#
/// ```
///
/// Rendering goes through `MathImageRenderer`'s cache, so identical
/// equations across many labels share bitmaps. Unsupported LaTeX renders
/// nothing by default (the never-half-broken contract — check `isRendered`
/// or opt into `displayErrorInline` to show the source in red).
public final class VinculumLabel: PlatformView {

    /// The LaTeX source to render.
    public var latex: String = "" { didSet { refresh() } }
    /// Display style (stacked limits, larger fraction parts). Default true —
    /// a standalone label is usually a display equation.
    public var displayMode: Bool = true { didSet { refresh() } }
    /// The math font. Default Latin Modern.
    public var font: MathFont = .latinModern { didSet { refresh() } }
    /// Ink + appearance.
    public var mathTheme: MathTheme = .light { didSet { refresh() } }
    /// Point size of surrounding text. Default 17.
    public var baseSize: CGFloat = 17 { didSet { refresh() } }
    /// Horizontal placement of the equation within the bounds.
    public var textAlignment: Alignment = .left { didSet { relayout() } }
    /// Padding between the rendered equation and the view's bounds.
    public var contentInsets: PlatformEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0) {
        didSet { relayout() }
    }
    /// When true, unsupported LaTeX shows its source in red instead of
    /// rendering nothing. Off by default: a document should degrade to the
    /// host's own fallback, never to a half-render.
    public var displayErrorInline: Bool = false { didSet { refresh() } }

    /// Whether the current `latex` rendered natively.
    public private(set) var isRendered: Bool = false

    public enum Alignment { case left, center, right }

    private let imageView = PlatformImageView()
    private let errorLabel = PlatformTextLabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        addSubview(imageView)
        addSubview(errorLabel)
        errorLabel.isHidden = true
    }

    private var imageSize: CGSize = .zero

    private func refresh() {
        let attributed = MathImageRenderer.attachmentString(
            latex: latex, display: displayMode, mathTheme: mathTheme,
            baseSize: baseSize, font: font)
        var image: PlatformImage?
        attributed?.enumerateAttribute(
            .attachment, in: NSRange(location: 0, length: attributed?.length ?? 0)) { value, _, _ in
            if let a = value as? NSTextAttachment, let i = a.image { image = i }
        }
        isRendered = image != nil
        imageView.setImage(image)
        imageSize = image?.size ?? .zero
        errorLabel.isHidden = isRendered || !displayErrorInline || latex.isEmpty
        if !errorLabel.isHidden { errorLabel.setErrorText(latex, size: baseSize) }
        relayout()
        invalidateIntrinsicContentSize()
    }

    private func relayout() {
        let insets = contentInsets
        let available = CGRect(x: insets.left, y: insets.top,
                               width: max(0, bounds.width - insets.left - insets.right),
                               height: max(0, bounds.height - insets.top - insets.bottom))
        let size = isRendered ? imageSize : errorLabel.naturalSize()
        let x: CGFloat
        switch textAlignment {
        case .left: x = available.minX
        case .center: x = available.minX + (available.width - size.width) / 2
        case .right: x = available.maxX - size.width
        }
        let frame = CGRect(x: x, y: available.minY + (available.height - size.height) / 2,
                           width: size.width, height: size.height)
        imageView.frame = frame
        errorLabel.frame = frame
    }

    public override var intrinsicContentSize: CGSize {
        let size = isRendered ? imageSize
            : (displayErrorInline && !latex.isEmpty ? errorLabel.naturalSize() : .zero)
        return CGSize(width: size.width + contentInsets.left + contentInsets.right,
                      height: size.height + contentInsets.top + contentInsets.bottom)
    }

    #if canImport(AppKit)
    public override func layout() { super.layout(); relayout() }
    public override var isFlipped: Bool { true }
    #else
    public override func layoutSubviews() { super.layoutSubviews(); relayout() }
    #endif
}

// MARK: - Tiny platform shims

private final class PlatformImageView: PlatformView {
    private var image: PlatformImage?
    func setImage(_ image: PlatformImage?) {
        self.image = image
        #if canImport(AppKit)
        needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }
    #if canImport(AppKit)
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: nil)
    }
    #else
    override func draw(_ rect: CGRect) { image?.draw(in: bounds) }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isOpaque = false }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    #endif
}

private final class PlatformTextLabel: PlatformView {
    private var text: String = ""
    private var fontSize: CGFloat = 17
    func setErrorText(_ text: String, size: CGFloat) {
        self.text = text; self.fontSize = size
        #if canImport(AppKit)
        needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }
    private var attributes: [NSAttributedString.Key: Any] {
        [.font: PlatformFont.monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular),
         .foregroundColor: PlatformColor.systemRed]
    }
    func naturalSize() -> CGSize {
        (text as NSString).size(withAttributes: attributes)
    }
    #if canImport(AppKit)
    override var isFlipped: Bool { true }
    #endif
    override func draw(_ rect: CGRect) {
        (text as NSString).draw(at: .zero, withAttributes: attributes)
    }
}
#endif
