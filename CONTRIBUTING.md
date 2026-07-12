# Contributing to Vinculum

Vinculum is the native math engine extracted from
[Quoin](https://github.com/clintecker/quoin), following the same pattern as
[MermaidKit](https://github.com/clintecker/MermaidKit).

## Architecture

The design mirrors TeX's device-independent split (and MermaidKit's): layout
decides WHAT to draw as a platform-free scene; a renderer decides HOW.

- **VinculumLayout** (platform-free, Foundation only, zero deps — builds on
  Linux) does parsing AND all typesetting geometry:
  - *Parse* — `MathTokenizer` (lexer), `MathParser` (recursive descent),
    `MathSymbolTable` (data), `MathScanner` (`$…$` delimiters), `MathMacros`
    (`\newcommand`/`\def`), `MathAlphabet` (Unicode math alphabets),
    `MathDiagnostics` (support classification). Model in `MathNode`.
  - *Lay out* — `MathLayoutEngine` measures glyphs through the injected
    `MathTextMeasurer` seam and emits a `MathScene` of positioned primitives
    (`MathElement`: glyph runs, rules, stroked paths) in `MathColor`. The
    per-domain builders live in `Layout+*.swift` (Fractions, Scripts,
    Radicals, Delimiters, Accents, OverUnder, Decorations); `MathBox` is the
    compositional unit; `MathConstants` holds the font's MATH-table metrics.
  - No CoreGraphics/CoreText/AppKit — only Foundation geometry types.
- **VinculumRender** (Apple platforms) is the thin platform seam:
  `CoreTextMeasurer` (implements `MathTextMeasurer` via CTLine),
  `MathSceneRenderer` (draws a `MathScene` to a `CGContext`), `MathFont`
  (the bundled Latin Modern Math), `MathTheme` (the host coupling: ink +
  appearance), and `MathImageRenderer` (cached `NSTextAttachment`,
  orchestrating measure → layout → render). Guarded `#if canImport(AppKit)
  || canImport(UIKit)`.

Because layout is measurement-injected, its geometry is unit-tested headless
with a mock measurer (`MathLayoutTests`) — on Linux, in CI.

## API stability (pre-1.0)

Entry points are stable: `MathParser.parse`, `MathParser.isFullySupported`,
`MathParser.unsupportedCommands`, `MathMacros`, `MathImageRenderer`,
`MathTheme`. The `MathNode` model and typesetter internals may reshape
until 1.0 as coverage grows (accents, arrays, a real OpenType MATH font).

## Tests

`swift test` runs the parser/macro suites (VinculumLayoutTests) and the
golden-image + typesetter suites (VinculumRenderTests). Golden PNGs live in
`Tests/fixtures/math-golden/` and are rendered with `MathTheme.light`;
regenerate with `VINCULUM_UPDATE_SNAPSHOTS=1 swift test`. The coverage
ledger is the fixture list itself: a `.knownUnsupported` fixture that
starts rendering FAILS the build until promoted, so the docs can never
overstate what's supported.

## Notes

- Swift tools 5.10 for now; a Swift 6 strict-concurrency pass is a planned
  follow-up (matching MermaidKit, which is already 6.0).
- Local green does not guarantee CI green — the iOS render branch has no
  test host but must compile, and Swift-version skew between local and CI
  is real. The CI builds `VinculumRender` for the iOS Simulator for exactly
  this reason.
