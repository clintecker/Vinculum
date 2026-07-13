# Vinculum Architecture

Vinculum is built on one idea, borrowed from TeX itself: **separate *what* to
draw from *how* to draw it.** TeX compiles a document to a device-independent
`DVI` file — a list of "put this glyph here, draw this rule there" — and a
separate driver rasterizes it for a specific device. Vinculum does the same
at the scale of a single expression: `MathLayoutEngine` produces a
device-independent `MathScene`, and `MathSceneRenderer` turns it into pixels.

This split is also MermaidKit's (layout vs. render), and it is why the entire
layout stage builds and unit-tests on Linux with no display.

---

## The two products

| | `VinculumLayout` | `VinculumRender` |
| --- | --- | --- |
| Depends on | Foundation only | VinculumLayout + CoreText/CoreGraphics/AppKit/UIKit |
| Platforms | macOS, iOS, visionOS, tvOS, **Linux** | Apple only |
| Owns | parsing, macros, **all typesetting geometry** | measuring, drawing, the bundled font, the theme, the cached attachment |
| Output | a `MathScene` (positioned primitives) | pixels / an `NSTextAttachment` |

`VinculumLayout` never imports CoreGraphics or CoreText. It uses only
Foundation geometry types (`CGPoint`, `CGRect`, `CGFloat`), which exist on
Linux, so it is fully portable and headless.

---

## The pipeline

```
LaTeX string
  │
  ▼  MathMacros.collectDefinitions / .expand      (VinculumLayout)
      \newcommand / \renewcommand / \def expanded, definitions stripped
  │
  ▼  MathParser.parse                              (VinculumLayout)
      Tokenizer → recursive-descent parser → MathNode tree
      (unknown commands become .unsupported leaves; parse never fails)
  │
  ▼  MathLayoutEngine.layout(node, display:)       (VinculumLayout)
      measures glyphs via the injected MathTextMeasurer,
      composes MathBoxes, flattens to positioned MathElements
  │
  ▼  MathScene { width, ascent, descent, elements }    ← the DVI analog
  │
  ├─▼ MathSceneRenderer.draw(scene, theme, ctx, at:)   (VinculumRender)
  │     glyph runs, rules, strokes → CGContext
  │
  └─▼ MathImageRenderer.attachmentString(...)          (VinculumRender)
        orchestrates measure→layout→render, caches, returns NSTextAttachment
```

---

## The device-independent scene IR

`MathScene` (in `MathScene.swift`) is the contract between the two products:

```swift
public struct MathScene: Sendable {
    public var width: CGFloat
    public var ascent: CGFloat      // above the baseline
    public var descent: CGFloat     // below the baseline
    public var elements: [MathElement]
    public var height: CGFloat { ascent + descent }
}
```

The scene's coordinate system is **y-up with the origin on the expression's
baseline**. `ascent`/`descent` are exactly what an inline attachment needs to
sit on a text baseline.

`MathElement` is the primitive vocabulary — deliberately three cases, enough
to draw all of math:

```swift
public enum MathElement: Sendable {
    case glyphs(text: String, size: CGFloat, mono: Bool, origin: CGPoint, color: MathColor?)
    case rule(CGRect, color: MathColor?)                 // fraction bars, over/underline, box sides
    case stroke(path: [PathOp], width: CGFloat,          // radical signs, braces, arrows, box borders
                cap: StrokeCap, join: StrokeJoin, color: MathColor?)
}
```

- `text` is already the *final* glyph string. Style (italic/bold, math
  alphabets) is baked in by remapping to Mathematical-Alphanumeric codepoints
  during layout (`MathLayoutEngine.mathVariant`, `MathAlphabet`), so the
  renderer needs no style flags — it just draws the string in the math font.
- `mono: true` selects the monospace fallback used only for `.unsupported`
  source, keeping unknown input legible.
- `PathOp` (`move`/`line`/`quad`/`close`) and Vinculum's own `StrokeCap` /
  `StrokeJoin` enums keep strokes platform-free — CoreGraphics' `CGLineCap`
  isn't on every platform.

`MathColor` is platform-free sRGB. A `nil` color on any element means **"use
the theme ink"**; the renderer substitutes `MathTheme.ink` at draw time.
`\color{red}{…}` / `\color{#cc2222}{…}` resolve to a concrete `MathColor`
during layout (`MathColor.resolve` handles a named palette and `#rrggbb`),
and that color rides on the element — so themes and per-subtree color compose
without the renderer knowing anything about `\color`.

---

## The measurer seam — why layout is headless

Layout must know glyph widths and heights, which only a real font system can
give. Rather than import CoreText into the layout product, Vinculum **injects**
the measurement:

```swift
public typealias MathTextMeasurer =
    @Sendable (_ text: String, _ size: CGFloat, _ mono: Bool) -> GlyphMetrics

public struct GlyphMetrics: Sendable {
    public var width, ascent, descent: CGFloat
    public var inkAscent, inkDescent: CGFloat   // actual painted bounds → accent placement
}
```

`MathLayoutEngine` is constructed with a measurer:

```swift
let engine = MathLayoutEngine(measure: someMeasurer, baseSize: 15)
```

- On Apple platforms, `CoreTextMeasurer.make()` implements it via `CTLine`
  (typographic bounds + `CTLineGetImageBounds` for the ink extents accents
  need).
- In tests (and on Linux), a **mock measurer** returns synthetic metrics, so
  `MathLayoutTests` asserts on exact geometry — fraction bar position, script
  shift, matrix cell placement — with no display and no font.

The seam is the whole reason the layout geometry is unit-testable in CI on a
headless Linux runner.

---

## Two kinds of constants: `MathConstants` vs. `MathLayout`

Knuth's rule (Appendix G of *The TeXbook*) is that a math typesetter reads its
constants **from the font**, never from hand-tuned literals. Vinculum follows
it, and splits its numbers into two files accordingly:

- **`MathConstants`** — values with an OpenType MATH-table equivalent, as em
  fractions of Latin Modern Math's real numbers: `axisHeight` (0.250),
  `fractionRuleThickness` (0.040), `superscriptShiftUp` (0.363),
  `subscriptShiftDown` (0.247), `radicalVerticalGap` (0.148),
  `scriptPercentScaleDown` (0.70), and so on. These are what TeX would read
  from the font.
- **`MathLayout`** (in `MathLayoutMetrics.swift`) — proportions that have *no*
  font parameter because TeX delegates them to *glyphs* (the radical hook, the
  curly brace, the arrowhead) or to the *style lattice* (the D→T→S→SS shrink).
  Vinculum draws those shapes itself, so their vertices and scales are named
  and documented here (`MathLayout.Radical`, `.Brace`, `.Arrow`, `.Fraction`,
  …) rather than left as bare literals. Inter-atom spacing lives beside them in
  `MathSpacing` as `mu` (1/18 em): thin 3mu, medium 4mu, thick 5mu.

The guiding invariant: **zero unexplained numbers in the builders.** If a value
has a font equivalent it is read from `MathConstants`; otherwise it is a named
`MathLayout` proportion with a comment saying why it has no font source.

---

## The atom-class spacing model

Vinculum spaces atoms the way TeX does — not by eyeballing gaps, but by
classifying each atom and looking up the pair in a table. Every `MathNode`
symbol carries a `MathAtomClass`:

```swift
enum MathAtomClass { case ordinary, largeOperator, binary, relation, opening, closing, punctuation }
```

`MathSymbolTable` assigns the class (e.g. `+` is `.binary`, `=` is
`.relation`, `∑` is `.largeOperator`, `(` is `.opening`). In `rowBox`, the
engine walks adjacent atoms and inserts spacing per `MathLayoutEngine.spacing(between:and:)`,
which encodes TeX's pair table (TeXbook p. 170):

- Ord↔Op → thin (3mu)
- around Bin → medium (4mu)
- around Rel → thick (5mu)
- after Punct → thin

This is why `a+b` and `a=b` and `\sum x` all get *correct* — and different —
spacing, and why a directly-typed `∫x` behaves like `\int x`:
`characterNode` looks the raw glyph up in `glyphAtomClass` (the reverse of the
symbol table) so it gets the same class its command spelling would.

---

## How to add a new command

Adding a construct touches up to three files. Two worked examples:

### A new symbol (e.g. `\aleph` were it missing)

1. Add one row to `MathSymbolTable.symbolTable`:
   ```swift
   "aleph": ("ℵ", .ordinary),
   ```
   That's it — the parser's `default` case looks commands up in the table and
   emits `.symbol(glyph, class, style: .roman)`, layout draws it, spacing falls
   out of the atom class. (Because the reverse map is built from this table,
   typing the raw glyph gets the same class for free.)

### A new structural command (e.g. a hypothetical `\undertilde`)

1. **Parser** — add a `case` in `MathParser.commandNode` that consumes the
   argument(s) and returns the right `MathNode`. Reuse an existing node kind if
   you can (accents, over/under, decorations, genfrac all take variants), or
   add a `MathNode` case if the shape is genuinely new.
2. **Layout** — add a builder in the matching `Layout+*.swift` extension (or a
   new one), dispatched from `MathLayoutEngine.box(for:size:display:)`. Build a
   `MathBox` from sub-boxes and primitives; use `MathConstants` for any value
   with a font source, otherwise a named `MathLayout` proportion.
3. **Diagnostics** — if you added a `MathNode` case, extend
   `MathParser.isFullySupported` and `unsupportedCommands` (both in
   `MathDiagnostics.swift`) to recurse into it, and `atomClass(of:)` if it needs
   a spacing class.
4. **Tests** — add a headless geometry assertion in `MathLayoutTests` (mock
   measurer) and, if it renders, a golden fixture the render suite diffs.

The parser's cardinal rule: **never fail.** Unknown commands become
`.unsupported` leaves so a document degrades to a named source card instead of
throwing. `isFullySupported` is the gate the render API checks before
committing to a native render.

---

## Rasterization and caching (`MathImageRenderer`)

`MathImageRenderer.attachmentString` is the orchestrator:

1. `MathParser.parse` → gate on `isFullySupported` (return `nil` if not).
2. Cache lookup keyed by `display | theme.fingerprint | baseSize | latex`.
3. On a miss: build the engine (display bumps `baseSize × 1.15`), lay out the
   scene, rasterize into an `NSImage`/`UIImage` at the scene's size + 2pt
   padding, pinning the theme's appearance (`.darkAqua`/`.aqua`) so dynamic
   inks resolve correctly.
4. Wrap the image in an `NSTextAttachment` whose `bounds` are offset by the
   scene descent, so it sits on the text baseline.

The cache is an `NSCache` (documented thread-safe). `MathTheme.fingerprint`
resolves the ink under the same appearance used to draw, so two themes that
differ only in ink can never serve each other's cached renders.
