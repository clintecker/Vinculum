# Changelog

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
