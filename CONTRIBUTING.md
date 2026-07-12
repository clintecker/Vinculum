# Contributing to Vinculum

Vinculum is the native math engine extracted from
[Quoin](https://github.com/clintecker/quoin), following the same pattern as
[MermaidKit](https://github.com/clintecker/MermaidKit).

## Layout

- **VinculumLayout** (platform-free, zero dependencies) — `MathParser`
  (LaTeX → `MathNode` tree), `MathScanner` (delimiter scanning),
  `MathAlphabet` (Unicode math-alphabet codepoints), `MathMacros`
  (document-scoped `\newcommand`/`\def` expansion). No CoreGraphics, no
  AppKit/UIKit — builds anywhere.
- **VinculumRender** (Apple platforms) — `MathTypesetter` (`MathNode` → a
  `MathBox` geometry tree, drawn with CoreText/CoreGraphics),
  `MathImageRenderer` (cached `NSTextAttachment` production), and the
  `MathTheme` seam (the sole host coupling: ink + appearance). Guarded
  `#if canImport(AppKit) || canImport(UIKit)`.

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
