#if canImport(AppKit) || canImport(UIKit)
import Foundation
import CoreText
import CoreGraphics
import VinculumLayout

/// Draws a device-independent `MathScene` into a CoreGraphics context — the
/// "how" that pairs with layout's "what". Glyph runs use the bundled math
/// font; `nil`-colored primitives take the theme ink; a `\color` element
/// carries its own resolved sRGB. The context is expected to be y-up (the
/// scene's convention).
enum MathSceneRenderer {

    /// Draws `scene` with its baseline origin placed at `origin`.
    static func draw(_ scene: MathScene, theme: MathTheme, in ctx: CGContext, at origin: CGPoint) {
        for element in scene.elements {
            switch element {
            case let .glyphs(text, size, mono, o, color):
                let ctFont: CTFont = mono
                    ? PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular) as CTFont
                    : (MathFont.ctFont(size: size) ?? PlatformFont.systemFont(ofSize: size) as CTFont)
                let attributed = NSAttributedString(string: text, attributes: [
                    kCTFontAttributeName as NSAttributedString.Key: ctFont,
                    kCTForegroundColorFromContextAttributeName as NSAttributedString.Key: true])
                let line = CTLineCreateWithAttributedString(attributed)
                ctx.saveGState()
                ctx.setFillColor(cgColor(color, theme))
                ctx.textPosition = CGPoint(x: origin.x + o.x, y: origin.y + o.y)
                CTLineDraw(line, ctx)
                ctx.restoreGState()

            case let .rule(r, color):
                ctx.saveGState()
                ctx.setFillColor(cgColor(color, theme))
                ctx.fill(CGRect(x: origin.x + r.origin.x, y: origin.y + r.origin.y,
                                width: r.size.width, height: r.size.height))
                ctx.restoreGState()

            case let .stroke(path, width, cap, join, color):
                ctx.saveGState()
                ctx.setStrokeColor(cgColor(color, theme))
                ctx.setLineWidth(width)
                ctx.setLineCap(cap.cg)
                ctx.setLineJoin(join.cg)
                ctx.beginPath()
                for op in path {
                    switch op {
                    case .move(let p): ctx.move(to: CGPoint(x: origin.x + p.x, y: origin.y + p.y))
                    case .line(let p): ctx.addLine(to: CGPoint(x: origin.x + p.x, y: origin.y + p.y))
                    case let .quad(to, control):
                        ctx.addQuadCurve(to: CGPoint(x: origin.x + to.x, y: origin.y + to.y),
                                         control: CGPoint(x: origin.x + control.x, y: origin.y + control.y))
                    case .close: ctx.closePath()
                    }
                }
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
    }

    private static func cgColor(_ color: MathColor?, _ theme: MathTheme) -> CGColor {
        guard let color else { return resolvedCGColor(theme.ink) }
        #if canImport(AppKit)
        return PlatformColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha).cgColor
        #else
        return PlatformColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha).cgColor
        #endif
    }
}

private extension StrokeCap {
    var cg: CGLineCap { switch self { case .butt: return .butt; case .round: return .round; case .square: return .square } }
}
private extension StrokeJoin {
    var cg: CGLineJoin { switch self { case .miter: return .miter; case .round: return .round; case .bevel: return .bevel } }
}
#endif
