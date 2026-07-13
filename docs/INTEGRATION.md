# Integrating Vinculum

A host-app guide: add the package, pick a theme, produce inline attachments,
and understand caching and threading. Vinculum was extracted from Quoin (a
native Markdown editor), so the integration story is "drop a math attachment
into a TextKit run" — but the pieces are exposed if you want more.

---

## 1. Add the package

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/clintecker/Vinculum.git", from: "0.5.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "VinculumRender", package: "Vinculum"),
    ]),
]
```

`VinculumRender` transitively re-exports the layout types you need
(`MathParser`, `MathScene`, `MathLayoutEngine`), so a typical Apple app imports
only `VinculumRender`. Import `VinculumLayout` directly only if you want the
platform-free layer alone (see §7).

The bundled **Latin Modern Math** font ships as a package resource — no font
installation, no `Info.plist` entry, nothing for the host to register.

---

## 2. The one seam: `MathTheme`

`MathTheme` is the entire coupling between Vinculum and your design system.
Math is monochrome ink on a transparent attachment, so it needs just two
things:

```swift
public struct MathTheme: Sendable {
    public let ink: PlatformColor    // NSColor on macOS, UIColor on UIKit
    public let prefersDark: Bool
    public init(ink: PlatformColor, prefersDark: Bool)

    public static let light = MathTheme(ink: .black, prefersDark: false)
    public static let dark  = MathTheme(ink: .white, prefersDark: true)
}
```

Use the presets, or build one from your palette:

```swift
let theme = MathTheme(ink: myDesignSystem.primaryTextColor,
                      prefersDark: traitCollection.userInterfaceStyle == .dark)
```

- `ink` colors every glyph and stroke, unless a `\color{…}{…}` subtree
  overrides it.
- `prefersDark` pins the appearance (`.darkAqua` / `.aqua`) while the image is
  rasterized, so a **dynamic/catalog color** resolves to the variant matching
  the canvas — and it is part of the cache key, so light and dark renders never
  collide.

**Light/dark:** build two themes (or rebuild on trait change) and re-request
the attachment; the cache keys on the theme fingerprint, so switching is a
cache hit after the first render of each appearance.

---

## 3. Produce an inline attachment

The one-call path returns an `NSAttributedString` wrapping a baseline-aligned
`NSTextAttachment`:

```swift
import VinculumRender

func mathRun(_ latex: String, display: Bool) -> NSAttributedString? {
    MathImageRenderer.attachmentString(
        latex: latex,
        display: display,          // true = display style (stacked limits, larger parts)
        mathTheme: currentTheme,
        baseSize: bodyFont.pointSize)   // match the surrounding text
}
```

Splice it into your text storage:

```swift
if let run = mathRun(#"\int_0^1 x^2\,dx = \tfrac{1}{3}"#, display: false) {
    textView.textStorage?.replaceCharacters(in: selectedRange, with: run)
} else {
    // Unsupported: keep the literal source, or caption why.
    let node = MathParser.parse(latex)
    let culprits = MathParser.unsupportedCommands(in: node)   // ["\\cancel", …]
    showSourceFallback(latex, because: culprits)
}
```

The attachment's `bounds` are offset by the scene descent, so it sits on the
text baseline and participates in line layout, selection, and line breaking
like any glyph. Works identically with `UITextView` on iOS/visionOS/tvOS —
the API returns `NSTextAttachment` on both.

**`display` vs. inline.** `display: true` uses display-style conventions
(limits stack over/under operators, fraction parts are larger) and internally
bumps the base size by 1.15×. Use it for standalone equation blocks; use
`display: false` for math inside a line of prose.

---

## 4. The `nil` contract — never a broken render

`attachmentString` returns `nil` **only** when the LaTeX contains an
unsupported command (it does not return `nil` for a mere typo — that renders as
whatever it parses to). This is deliberate: a document should degrade to a
readable source fallback, never a half-drawn equation. Always keep your own
fallback path. To explain the fallback, call:

```swift
let node = MathParser.parse(latex)
if !MathParser.isFullySupported(node) {
    let names = MathParser.unsupportedCommands(in: node, limit: 4)  // first-seen, deduped
    // e.g. "Contains \\genfrac"
}
```

---

## 5. Caching behavior

- `MathImageRenderer` caches rendered images in an `NSCache`, keyed by
  `display | theme.fingerprint | baseSize | latex`. Re-requesting the same
  equation at the same size and theme is a dictionary hit — cheap to call in a
  `layoutManager` / cell-reuse loop.
- The cache is memory-pressure aware (that's what `NSCache` gives you); you
  don't manage eviction.
- Changing `baseSize` or theme produces a distinct entry — expected, since the
  raster differs. If you support dynamic type or theme switching, the first
  render at each configuration pays layout cost; subsequent ones are hits.
- There is no manual "clear cache" API; the cache is process-lifetime and
  self-trimming.

---

## 6. Thread-safety

- **Layout is `Sendable` and main-thread-independent.** `MathParser`,
  `MathNode`, `MathScene`, `MathElement`, `MathColor`, `MathTheme`,
  `GlyphMetrics`, and `MathLayoutEngine` are all `Sendable`; the measurer
  typealias is `@Sendable`. Parsing and `engine.layout(...)` can run on any
  queue — precompute scenes off the main thread if you like.
- **`CoreTextMeasurer.make()`** returns a `@Sendable` closure over an immutable
  `CGFont`; safe to share across threads.
- **`MathImageRenderer`'s cache** is an `NSCache` (documented thread-safe).
- **Rasterization** uses platform image APIs (`NSImage(size:flipped:)` /
  `UIGraphicsImageRenderer`). These are not `@MainActor`-isolated in Vinculum,
  but follow your platform's norms for image creation; the safest pattern is to
  request attachments from the main actor if you're driving a text view there,
  and precompute *scenes* (pure geometry) off-main when you want to parallelize.

A common pattern: parse + lay out many equations concurrently into `MathScene`
values (pure `Sendable` geometry), then hop to the main actor to draw or build
attachments.

---

## 7. Using the platform-free layout product

Want to render math on Linux, in SwiftUI `Canvas`, in a Metal pipeline, or to
PDF — anywhere that isn't a text attachment? Depend on **VinculumLayout**
alone and supply your own measurer + renderer.

```swift
import VinculumLayout   // Foundation only; builds on Linux

// 1. Supply a measurer. On Apple platforms, CoreTextMeasurer.make() exists in
//    VinculumRender; on Linux, implement the closure with your font system.
let measure: MathTextMeasurer = { text, size, mono in
    // return GlyphMetrics(width:ascent:descent:inkAscent:inkDescent:)
    myFontEngine.metrics(of: text, size: size, mono: mono)
}

// 2. Lay out to a device-independent scene.
let node  = MathParser.parse(#"\sqrt{a^2 + b^2}"#)
let scene = MathLayoutEngine(measure: measure, baseSize: 17).layout(node, display: true)

// 3. Walk scene.elements yourself:
for element in scene.elements {
    switch element {
    case let .glyphs(text, size, mono, origin, color): // draw text
    case let .rule(rect, color):                        // fill rect
    case let .stroke(path, width, cap, join, color):    // stroke path
    }
}
```

The scene is y-up with the origin on the baseline; `scene.width`,
`scene.ascent`, `scene.descent` give you the bounding box. A `nil` element
color means "use your ink"; a non-nil `MathColor` is a resolved `\color` you
should honor.

**SwiftUI:** lay out a `MathScene` off-main, then translate `scene.elements`
into `Path`/`Text` inside a `Canvas` — the same three primitives.

---

## 8. Macros across a document

If your host has multiple math blocks that share `\newcommand` definitions,
collect them once and expand each block:

```swift
import VinculumLayout

let table = MathMacros.collectDefinitions(from: entireDocumentText)  // scans all math segments
let expanded = MathMacros.expand(oneBlockLatex, with: table)
let node = MathParser.parse(expanded)
```

`collectDefinitions` uses `MathScanner` to find `$…$` / `$$…$$` segments, so a
`\newcommand` written in prose or a code fence is ignored. Definitions are
document-scoped and order-independent; `\renewcommand` (and a later `\def`)
wins.
