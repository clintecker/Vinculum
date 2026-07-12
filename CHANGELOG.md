# Changelog

## 0.3.0 — 2026-07-12

Two big things since 0.1.0: an OpenType MATH font for genuine LaTeX quality,
and a device-independent scene-IR re-architecture.

**Latin Modern Math (Computer Modern).** Real glyph shapes, codepoint-based
math italics (variables → Mathematical Italic block, lowercase Greek italic),
the font's MATH-table constants, and ink-hugging accent placement — plus
standalone delimiters (`\langle` outside `\left…\right`) and ~80 more symbols.

**Scene IR.** A radical decomposition mirroring TeX's DVI split and
MermaidKit's layout/render seam. No change to rendered output (the golden
fixtures pass byte-identical), but the internals are now:

- **VinculumLayout is fully platform-free** and owns all typesetting geometry.
  `MathLayoutEngine` measures glyphs through an injected `MathTextMeasurer`
  and emits a `MathScene` of positioned primitives (`MathElement` / `MathColor`
  / `MathConstants`). Builds and tests on **Linux** (headless, mock measurer).
- **VinculumRender shrank to the platform seam**: `CoreTextMeasurer`,
  `MathSceneRenderer`, `MathFont`, `MathTheme`, `MathImageRenderer`. The old
  876-line `MathTypesetter` is gone.
- The two 800-line monoliths are now ~25 single-responsibility files (largest
  452 lines).
- **Swift 6** language mode + strict concurrency; platforms add **tvOS 17**.
- Public API unchanged: `MathParser`, `MathImageRenderer.attachmentString`,
  `MathTheme`. New public surface: `MathLayoutEngine`, `MathScene`,
  `MathTextMeasurer` for hosts that want the device-independent scene.

## 0.1.0 — 2026-07-11

First release. The native LaTeX math engine extracted from
[Quoin](https://github.com/clintecker/quoin), sibling to
[MermaidKit](https://github.com/clintecker/MermaidKit).

**VinculumLayout** (platform-free): `MathParser` (LaTeX → `MathNode` tree,
never fails — unknown commands degrade to `.unsupported` leaves that
`unsupportedCommands(in:)` can name), `MathScanner` (delimiter scanning),
`MathAlphabet` (Unicode math-alphabet codepoints), `MathMacros`
(document-scoped `\newcommand`/`\def` expansion, recursion-capped).

**VinculumRender** (CoreText/CoreGraphics): `MathTypesetter` (`MathNode` →
`MathBox` geometry — fractions, radicals, scripts, stacked limits,
matrices, accents, generalized fractions, over/under braces, stretchy
arrows, boxed/phantom, color), `MathImageRenderer` (cached
`NSTextAttachment` production), and the `MathTheme` seam.

Coverage: everyday KaTeX — fractions, roots, scripts, big operators with
limits, all matrix environments, `\mathbb`/`\mathcal`/`\mathfrak`/…
alphabets, accents, `\binom`, `\overbrace`/`\underbrace`, `\xrightarrow`,
`\substack`, `\boxed`, `\color`, and document macros. ~35 golden-image
fixtures with a promotion ratchet. Swift tools 5.10; Swift 6
strict-concurrency pass is a planned follow-up.
