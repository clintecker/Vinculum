# Vinculum

**Native LaTeX math typesetting for macOS, iOS, and visionOS. No MathJax,
no KaTeX, no WebView, zero dependencies.**

Vinculum parses LaTeX math into a TeX-style node tree and lays it out with
CoreText and CoreGraphics — real inter-atom spacing, stacked big-operator
limits, radicals, matrices, accents, generalized fractions, over/under
constructs, and document-scoped `\newcommand` macros — then hands you a
baseline-aligned `NSTextAttachment`, an image, or a PDF.

*A vinculum is the bar in a fraction, the line over a root — the stroke
that binds an expression together.* It is the native math engine extracted
from [Quoin](https://github.com/clintecker/quoin), sibling to
[MermaidKit](https://github.com/clintecker/MermaidKit).

```swift
import VinculumRender

// A baseline-aligned attachment for a text view (nil if unsupported —
// the caller keeps its own fallback so a document never breaks):
let run = MathImageRenderer.attachmentString(
    latex: #"\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#,
    display: true,
    mathTheme: .light,
    baseSize: 15)

// Or drive the pieces directly:
let node = MathParser.parse(#"\sum_{i=1}^{n} i^2"#)   // VinculumLayout
if MathParser.isFullySupported(node) {
    let box = MathTypesetter(mathTheme: .dark, baseSize: 15).layout(node, display: true)
    // box.draw(cgContext, at: penPoint)
}
```

## What it renders

CommonMark-adjacent LaTeX math that people actually write:

- Fractions, `\sqrt[n]{}`, sub/superscripts, `\left…\right` auto-sized fences
- Big operators with stacked limits (`\sum` `\int` `\prod`), all six matrix
  environments, `cases`, `aligned`/`align`/`gather`/`split`
- Greek, ~130 symbols, and the math alphabets `\mathbb` `\mathcal`
  `\mathscr` `\mathfrak` `\mathsf` `\mathtt` (mapped to real Unicode glyphs)
- Accents (`\hat \vec \bar \dot \tilde`, stretchy `\widehat`,
  `\overline`/`\underline`), `\binom`/`\cfrac`, `\overset`/`\underset`,
  `\overbrace`/`\underbrace`, `\xrightarrow`, `\substack`
- `\boxed`, `\phantom`, `\color`/`\textcolor` (named + `#hex`)
- Directly-typed Unicode math (`∫ ∑ ≤ α`), classed like its command form
- Document-scoped `\newcommand`/`\renewcommand`/`\def`

Unsupported constructs return `nil` from the render API (never a broken
half-render), and `MathParser.unsupportedCommands(in:)` names the command
so a host can say *why*.

## The one seam: `MathTheme`

The renderer's only coupling to a host is `MathTheme` (ink color +
`prefersDark`). Use `.light`/`.dark`, or build one from your design system.
That's the whole surface — mirroring MermaidKit's `DiagramTheme`.

## License

MIT © 2026 Clint Ecker.
