# Changelog

## 0.6.0 — 2026-07-12

Everyday-correctness batch (from the typesetting review) — the fidelity gaps
that bite common writing. Rendering changes; goldens regenerated and visually
verified.

- **Named operators stack their limits.** `\lim`, `\max`, `\min`, `\sup`,
  `\inf`, `\det`, `\gcd`, `\limsup`, … now put their limit *underneath* in
  display style (`\lim_{x\to0}`), like TeX. They parse to function names,
  which the stacked-limits path previously missed.
- **Integrals keep side-scripts.** `\int`, `\oint`, `\iint` no longer
  over-stack in display — they default to `\nolimits` (scripts to the side),
  while `\sum`-class operators still stack. Limit-taking is now decided per
  operator, not by node shape.
- **Primes render as raised glyphs.** `f'`, `f''`, `f'''` become raised,
  coalesced primes (`′`) instead of baseline apostrophes; `f'^2` merges the
  prime with the explicit exponent.
- **Spaces survive inside `\text{…}`.** `\text`, `\mathrm`, `\operatorname`,
  `\textrm` bodies are captured verbatim by the tokenizer, so `\text{if } x`
  keeps its space (and nested braces).
- **Scripts clear tall bases and can't collide.** Super/subscript shifts now
  rise to clear a tall nucleus's ink (an exponent on `(…)²` rides above the
  paren) and a minimum gap is kept between a coexisting super- and subscript
  (TeX Appendix G).

Internal: the `^`/`_`/prime attachment is now one shared helper (was
duplicated across `parseRow` and `parseAtomWithScripts`). +6 tests (83 total).

## 0.5.0 — 2026-07-12

Performance, platform-fitness, and robustness pass, informed by a four-lens
expert review (Apple-platform architecture, performance, Swift/API quality,
typesetting correctness).

**Performance** (realistic load = a live editor re-projecting hundreds of
equations per keystroke):
- **Cache lookup now precedes parsing.** The render cache key is fully
  determined by the arguments, so a hit — positive *or* negative — costs no
  parse or layout. Previously every cache hit re-parsed the LaTeX (~15× on a
  matrix), and unsupported input re-parsed on every re-projection forever;
  unsupported/degenerate results are now remembered as negative entries.
- **Glyph measurement is memoized.** The parser emits one node per character,
  so an N×N matrix of identical entries re-measured each glyph N² times
  (~95% redundant, ~200 CoreText calls for an 8×8 of 15 unique glyphs). A
  shared, lock-guarded `(text, size, mono)` cache turns those into dictionary
  hits (~5× on matrix/large-expression cold renders).
- **CTFont creation is cached** by size (used by both measurement and drawing).

**Platform fitness:**
- **Tintable template images.** When a scene has no explicit `\color`, the
  attachment is emitted as a template image, so selected math inverts with the
  surrounding run and dark-mode adapts without a host re-render. Colored math
  stays baked. (`MathScene.hasExplicitColor` is new public API.)
- **iOS dynamic-ink correctness.** Rasterization pins the trait style so a
  dynamic `UIColor` ink resolves to the variant matching the theme's canvas,
  matching the macOS path.
- **Bounded render cache** (count + pixel-byte cost) instead of memory-pressure
  eviction only.
- **Consistent color across platforms.** `\color` builds its `CGColor` directly
  in sRGB, so AppKit and UIKit render an identical color.

**Robustness / quality:**
- The accent parser no longer force-unwraps `MathAccent(command:)` — it
  degrades to `.unsupported` if the case list and initializer ever drift,
  honoring the never-crash contract every other command already follows.
- Removed a dead `max` branch in the fraction descent and an orphaned doc
  comment; zero build warnings.

Public API additions: `MathScene.hasExplicitColor`, `MathElement.color`.

## 0.4.0 — 2026-07-12

**Every magic number is now a named font parameter.** Following Knuth's rule
that math typesetting reads its constants from the font, never from literals
(Appendix G of *The TeXbook*), the ~35 hand-tuned multipliers scattered
through the layout builders were replaced:

- Values with an OpenType MATH-table equivalent now read the font's real
  number from `MathConstants` — the axis (0.26→**0.250**), fraction/radical/
  overbar rules (0.045→**0.040**), script scale (0.68→**0.70**), superscript
  raise (0.42→**0.363**), subscript drop (0.20→**0.247**), radical gap
  (0.12→**0.148**), overbar gap (0.08→**0.120**). Rendering now matches what
  real LaTeX produces; goldens regenerated.
- Inter-atom spacing is expressed in `mu` (1/18 em) via `MathSpacing`
  (thin/medium/thick = 3/4/5 mu), the unit TeX actually uses.
- Vinculum's own drawing proportions — the hand-stroked radical hook, the
  brace arcs, the arrowhead, the style-lattice shrink — have no font
  parameter, so they are named and documented in `MathLayout` instead of
  left as bare literals. Zero unexplained numbers remain in the builders.

Public API unchanged.

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
