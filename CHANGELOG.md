# Changelog

## Unreleased

Phase 9a: spoken math — VoiceOver reads the equation, a native-library
first.

- **`MathSpeech.describe(MathNode)`** generates ClearSpeak-style utterances
  from the same tree that was typeset ("x equals the fraction minus b plus
  or minus the square root of b squared minus 4 a c, over 2 a"), covering
  fractions (with "1 half"-style simple forms), roots, scripts
  (squared/cubed/to-the-power), fences, matrices (row-by-row), cases,
  binomials ("n choose k"), accents ("vector v", "x hat"), operators, and
  ~80 spoken symbol names. Invisible nodes (spacing, phantoms) are silent.
- Wired everywhere: `VinculumLabel` and `MathView` expose it as their
  accessibility label, and every `MathImageRenderer` attachment image
  carries it — so math in an `NSTextView`/`UITextView` reads aloud too.

Phase 8 (a+b): round-trip and drop-in views.

- **`MathNode.toLaTeX()`** — every node kind serializes back to LaTeX,
  proven render-equivalent (scene-identical) and idempotent over a
  23-expression corpus. The substrate for copy-as-LaTeX, editing, and
  spoken-math accessibility.
- **`VinculumLabel`** (AppKit/UIKit) — `label.latex = "…"` and done:
  alignment, content insets, font/theme/size, intrinsic sizing, and
  opt-in `displayErrorInline` (OFF by default — unsupported input renders
  nothing, preserving the never-half-broken contract; `isRendered` tells
  the host to use its fallback).
- **`MathView`** (SwiftUI) — `MathView("e^{i\pi}+1=0").mathFont(.pagella)`
  with `.inlineStyle()`, `.mathTheme()`, `.mathSize()` modifiers.

Phase 7: multi-font — four bundled math fonts, or bring your own.

- **`MathFont` is now a value you pick**: `.latinModern` (default),
  `.termes` (Times companion), `.pagella` (Palatino companion), and
  `.stixTwo` — plus `MathFont(url:)` for any OTF with a MATH table. Pass
  `font:` to `MathImageRenderer.attachmentString` / `MathSceneRenderer.draw`
  or build providers with `CoreTextMeasurer.make(font:)` et al. Every
  font's MATH table (constants, glyph typography, variants, assemblies)
  is parsed once at load; caches key on the font.
- **STIX Two lights up cut-in kerning for real** — it ships MathKernInfo
  for 233 glyphs, so Phase 3's staircase kerning now runs on live font
  data, a first for native math rendering.
- Per-font raw MATH-table fixtures committed (Linux-testable) and
  per-font canary goldens (`canary-termes/pagella/stixtwo`) pin the same
  equation under each font. Existing Latin Modern goldens: zero churn.
- Fonts are GUST-GFL (TeX Gyre) / OFL (STIX Two) licensed; licenses ship
  in the bundle beside the fonts.

Phase 6: display operators from the font + TeX fence sizing.

- **Display-size operator variants** — in display style, ∑ ∏ ∫ and every
  large operator swap in the font's bigger cut (`DisplayOperatorMinHeight`,
  1.3 em in LM Math), centered on the math axis, replacing the 1.35×
  scale (which survives headless). `\int` in display is finally the tall
  slanted integral.
- **Rule 13a limit clearances** — stacked limits attach at
  `max(Upper/LowerLimitGapMin, BaselineRiseMin − d(sup) / DropMin − h(sub))`
  instead of a single stack gap.
- **Rule 19 fence sizing** — `\left…\right` heights follow TeX's
  `\delimiterfactor`/`\delimitershortfall` formula (ψ from the axis,
  ≥ max(2ψ·0.901, 2ψ − 5pt)), so fences carry TeX's proportions instead
  of enveloping the body completely.
- 4 new tests (`MathOperatorSizingTests`); 32 goldens re-blessed.

Phase 5b: the radical is the font's √ glyph.

- **Font surd** — `\sqrt` draws Latin Modern's radical glyph via size
  variants (nested radicals step through purpose-drawn cuts exactly like
  TeX), assembling from parts beyond the largest variant; glyph excess
  splits into the radicand clearance (Rule 11's ψ centering). The
  hand-stroked polyline remains only as the headless/no-provider fallback.
- **Shortfall heuristic** (`Construction.bestVariant`): a variant within
  3% of the target beats a ≥1.3× jump, keeping signs snug — applied to
  all delimiter variant selection.
- **Font-true degree placement** — `RadicalKernBeforeDegree` (0.278 em),
  `RadicalKernAfterDegree` (−0.556 em, tucking the sign back over the
  degree), and the 60% bottom-raise replace the hand proportions in the
  glyph path.
- 4 new tests (`MathRadicalTests`); 10 radical goldens re-blessed.

Phase 5a: glyph assembly — arbitrarily tall fences from font parts.

- **`MathAssemblySolver`** (pure, Linux-tested): OpenType GlyphAssembly
  placement — fewest extender repeats whose reachable range covers the
  target, joint overlaps opened equally from the maximum, respecting
  `MinConnectorOverlap`; degenerate extenders (advance ≤ 0) rejected at
  parse. `MathTableParser.variants` now reads the full `MathVariants`
  sub-table (ladders + assemblies + minConnectorOverlap), fixture-tested.
- **The stretch chain is complete**: size variants → glyph assembly →
  scaling. A fence taller than the largest variant (~3 em) is now BUILT
  from the font's caps and extenders at constant stroke weight (new
  `assembly-tall` golden: a 9 em paren). Assemblies render as stacked
  glyph-ID elements; no scene format change.
- **The `()[]{}`-only gate is gone** — `MathVariantTable` is backed by the
  fixture-tested parser (the old in-place parser mis-mapped some coverage),
  so `⟨ ⟩ ‖ ⌈ ⌉ ⌊ ⌋` and every other covered delimiter now step through
  true size variants (new `tall-angle` golden). `\vec`/accent marks now
  sit at the font's attachment points (combining-mark data honored).
- 8 new tests (`MathAssemblyTests`); goldens re-blessed after review.

Phase 4: accents placed by the font.

- **`topAccentAttachment` skew** — the accent's x position is the base
  glyph's attachment point minus the accent glyph's own (advance-center
  fallback), so `\hat{f}` leans with the letter. Strictly better than
  TeX's `\skewchar` mechanism.
- **`AccentBaseHeight` seat** — the accent hugs the base's ink but never
  sinks below the font's designed accent height (the constant was defined
  and unused since 0.x; now honored: δ = min(h, AccentBaseHeight)).
- **Script promotion** — `\hat{f}^2` attaches the ² to the f under the
  hat's reach (TeX Rule 12's single-character accentee rule), instead of
  scripting the whole accent box.
- 4 new geometry tests (`MathAccentTests`).

Phase 3: per-glyph script typography — italic correction and cut-in
kerning. No native math library has the latter.

- **Italic correction (Rules 17/18f/13a)** via a new injected
  `MathGlyphTypographyProvider` (backed by the font's parsed
  MathItalicsCorrectionInfo; `CoreTextTypographyProvider` on Apple,
  optional/neutral headless): superscripts shift right by δ while
  subscripts stay at the advance (`f^2_3` splits correctly), large
  operators tuck the subscript δ LEFT under the overhang (`\int_a^b` —
  ∫'s δ is 0.332 em), and stacked limits split ±δ/2.
- **The full Rule 18 ladder**: σ₁₈/σ₁₉ baseline drops for composite nuclei
  (fractions, fenced groups), `SuperscriptBottomMin`/`SubscriptTopMax`
  clamps, and 18d–e collision resolution via `SubSuperscriptGapMin` +
  `SuperscriptBottomMaxWithSubscript` (replacing the 4·ruleThickness
  heuristic). `SpaceAfterScript` now trails the scripts (it preceded them).
- **MathKernInfo cut-in kerning**: scripts sample the base glyph's corner
  kern staircase at their near edge — mechanics live and tested with
  synthetic data (LM Math ships no MathKernInfo; STIX Two, arriving with
  multi-font support, does).
- 7 new geometry tests (`MathScriptTypographyTests`); 19 goldens
  re-blessed after visual review.

Phase 2: the TeX style lattice — plus a long-standing fence-rendering bug
found and fixed. (Phases 0–1 below.)

- **`MathStyle` (display/text/script/scriptScript)** replaces the internal
  `display: Bool`, giving the full eight-style lattice with the existing
  cramped flag. TeX successor maps (`scriptStyle`, `fractionStyle`) thread
  through every builder. `MathNode.mathStyle` now carries a `MathStyle`
  (breaking for exhaustive matchers).
- **Style-true geometry** — medium/thick inter-atom spacing vanishes in
  script styles (TeX ch. 18): `\sum_{i=1}^{n}`'s lower limit tightens.
  Nested scripts land on TeX sizes: 70% then the 50% scriptscript floor,
  not 0.7ⁿ compounding shrink. Fractions use the font's Rule 15b–d
  constant pairs (`FractionNum/DenomShift` + `GapMin`, display vs text;
  stacks use the `StackTop/Bottom` pairs) — the 1.35 display boost and the
  hand-tuned `ruleGap`/`atopGap` retire. `\cfrac` uses the display pair.
- **`\displaystyle` / `\textstyle` / `\scriptstyle` / `\scriptscriptstyle`**
  — stateful to the rest of the group (like stateful `\color`), forcing
  both the style and the size it implies. `\genfrac`'s style argument now
  honors all four values (2/3 properly shrink).
- **Fixed: variant fences drawn at the previous text run's position.**
  `CTFontDrawGlyphs` positions go through the context's text matrix, which
  `saveGState` does not protect — every MATH-variant delimiter drawn after
  a glyph run landed shifted right (visible as `\binom`'s right paren
  overlapping the following `=` since 0.23). The renderer now resets the
  text matrix; every fenced golden improved.
- 33 golden fixtures re-blessed after visual review; 8 new geometry tests
  (`MathStyleTests`) pin the lattice headless.

Phase 1: MATH-table constants parsed from the font (and Phase 0's docs +
fixtures below).

- **`MathTableParser`** (VinculumLayout, platform-free): parses the raw
  `MATH` table's full 56-value `MathConstants` sub-table into
  `MathFontConstants`, and the `MathGlyphInfo` sub-table — per-glyph italic
  corrections (1,002 glyphs in LM Math), `topAccentAttachment` (2,475),
  extended shapes (250), and MathKernInfo cut-in kern staircases — into
  `MathGlyphInfo`. Bounds-checked, `nil` on malformation, fixture-tested
  headless against committed table bytes and fontTools ground truth.
- **The engine now carries the constants as data.**
  `MathLayoutEngine(…, constants:)` defaults to the `.latinModern` preset;
  `MathImageRenderer` passes `MathFont.constants`, parsed once from the
  live bundled font. The static `MathConstants` enum is deprecated. This is
  the keystone for multi-font support (roadmap Theme F).
- **The parser oracle caught three transcription bugs** in the old
  hardcoded constants, now fixed font-true: `spaceAfterScript` 0.041 →
  **0.056** (scripts breathe slightly more), `radicalVerticalGap` 0.148 was
  the *display* value — text style now uses the font's **0.050** (inline
  radicals hug their radicand like real TeX), and `stackGapMin` 0.150 →
  **0.120** (stacked limits sit slightly tighter). 36 golden fixtures
  re-blessed after visual review; `MathGlyphInfo` is parsed but not yet
  consumed (that's Phases 3–4: italic correction, cut-in kerning, accent
  attachment).

Phase 0 of the best-in-class plan (docs + fixtures, no behavior change).

- **Roadmap + phased implementation plan.** New
  [docs/ROADMAP.md](docs/ROADMAP.md) (release-level: font truth → style
  lattice → script typography/cut-in kerning → accents → glyph assembly →
  multi-font → DX → accessibility/firsts) and
  [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (phase-by-phase,
  test-first), grounded in a mechanism-level audit against iosMath v2.5.0.
- **docs/ALGORITHM.md** — honest rule-by-rule TeX Appendix G audit of the
  current engine (Implemented / Partial / Deviation / ABSENT), with a
  constants ledger and a gap→phase map. The doc the README answers to.
- **Raw MATH-table fixtures.** `Tests/fixtures/math-table/
  latinmodern-math.bin` (the font's raw `MATH` table), regenerated via the
  env-gated `MathTableFixtureExtraction` test
  (`VINCULUM_UPDATE_MATH_FIXTURES=1`), sanity-checked headless by
  `MathTableFixtureTests` — the Linux-testable ground truth Phase 1's
  constants/glyph-info parser will be developed against.
- **README honesty pass** — the metrics claims now say "test-pinned
  transcription of Latin Modern's MATH-table values" (font-parsed at
  runtime is Phase 1), and the iosMath comparison names where iosMath is
  currently ahead.

## 0.23.0 — 2026-07-13

Delimiter size-variants (the big one) + `\cancelto`.

- **Discrete delimiter size-variants from the font's MATH table.** Tall
  `\left…\right` fences now use the font's purpose-drawn size-variant glyphs
  (constant stroke weight) instead of continuous point-scaling (which fattened
  strokes). New: a runtime OpenType **MATH**-table parser
  (`MathVariantTable` reads `MathVariants` → vertical glyph construction), a
  glyph-by-ID scene primitive (`MathScene.glyph(id:)`), and an injected,
  optional `MathDelimiterProvider` seam (nil on Linux/headless → the old
  scaling path, so no regression). Engaged for clearly-tall fences of the
  verified delimiters `( ) [ ] { }`; other delimiters and short stretches use
  scaling. (Extensible assembly for arbitrarily-tall fences, and the remaining
  delimiters, are the staged follow-up.)
- **`\cancelto{target}{expr}`** — strike-through with a raised target label.

`\sideset` and `\mathchoice` remain a low-frequency tail. All CIs green.

## 0.22.0 — 2026-07-13

Box & rule decorations (Batch 15).

- **`\fbox`** — framed box (like `\boxed`).
- **`\colorbox{bg}{…}`** / **`\fcolorbox{border}{bg}{…}`** — filled background
  box, optionally framed (new `.colorbox` node; background rule drawn behind
  the content).
- **`\rule{w}{h}`** — a solid filled rectangle at explicit em/pt lengths (new
  `.ruleBox` node).
- **`\raisebox{shift}{…}`** — vertically shift the content (new `.raised`
  node).

`\sideset` and `\mathchoice` remain a low-frequency tail. +3 nodes.

## 0.21.0 — 2026-07-13

Over/under constructs & accents (Batch 14).

- **`\overbracket` / `\underbracket`** — square-bracket (⎴/⎵) over/under the
  content, with `^`/`_` labels.
- **`\overparen` / `\underparen`** — parenthesis-arc (⏜/⏝) over/under.
- **`\widecheck`** — stretchy check accent.

New `MathOverUnder` cases + `horizontalBracket`/`horizontalParen` stroke
helpers; `MathAccent.widecheck`. (`\cancelto`, `\utilde`, harpoon accents are a
small remaining tail.)

## 0.20.0 — 2026-07-13

True **`\cfrac`** continued fractions. Parts now lay out at full display size
(no per-level shrink) with the denominator aligned — `\cfrac[l]` / `\cfrac[r]`
/ default center. New `.cfrac(numerator:denominator:align:)` node, isolated
from the shared `\frac`/`\genfrac` path. Goldens for the nested continued
fraction regenerated (now full-size at every level).

## 0.19.0 — 2026-07-13

Operator & atom-class machinery (Batch 12).

- **Atom-class overrides:** `\mathbin \mathrel \mathop \mathord \mathopen
  \mathclose \mathpunct \mathinner` force the inter-atom spacing class of a
  subexpression (new transparent `.classified` node; `\mathop` also takes
  display limits).
- **`\pmb`** (poor-man bold) → rendered bold.
- **Stateful `\color{name}`** — the one-arg form now applies to the rest of the
  current group (`{\color{red} a+b} + c`), in addition to the localized
  `\color{name}{body}` / `\textcolor{name}{body}` forms.

`\DeclareMathOperator` is a planned follow-up (needs a macro-table branch).
+2 tests (117 total).

## 0.18.0 — 2026-07-12

Environment fixes (Batch 13) — two real parser bugs + two new environments.

- **`alignat{n}` bug fixed.** The mandatory `{n}` column-count argument was not
  consumed, so it leaked into the first cell. Now consumed (like `alignedat`).
- **`matrix*[r]` / `pmatrix*[r]` bug fixed.** The optional `[l|c|r]` alignment
  bracket leaked as literal `[ r ]` into cell 1. Now consumed and applied —
  uniform column alignment via the array path (great for signed numeric
  matrices). The `.array` alignment falls back to the last spec entry, so one
  entry covers all columns.
- **`gathered`** and **`multline`/`multline*`** now lay out aligned (were
  falling through to a centered grid).

+2 tests (115 total).

## 0.17.0 — 2026-07-12

Symbol sweep (Batch 11) — **157 new symbols** with correct TeX atom classes
(so inter-atom spacing is right), taking the table to ~400 commands.

- **Relations:** `\leqslant \geqslant \eqsim \approxeq \lessapprox \gtrapprox
  \lll \ggg \leqq \geqq \subseteqq \supseteqq \Subset \Supset \frown \smile
  \vDash \Vdash \multimap \trianglelefteq \pitchfork …`
- **Negations:** `\nleq \ngeq \nless \ngtr \nsim \ncong \nprec \nsucc \nvdash
  \subsetneqq \lneq \gneq \lnsim \gnsim \ntrianglelefteq …`
- **Arrows:** `\rightsquigarrow \twoheadrightarrow \dashrightarrow
  \circlearrowleft \curvearrowright \leftrightarrows \Rrightarrow \longmapsto
  \nrightarrow \looparrowright …`
- **Harpoons:** `\leftharpoonup \rightharpoondown \upharpoonright
  \leftrightharpoons …`
- **Binary ops:** `\ltimes \rtimes \Cap \Cup \barwedge \veebar \boxdot
  \circledast \dotplus \lessdot \gtrdot \intercal …`
- **Letterlike:** `\hslash \Bbbk \digamma \varkappa \varrho \lozenge
  \blacktriangle \measuredangle \sphericalangle \beth \gimel \daleth …`

+3 fixtures; all render with real font glyphs (no tofu).

## 0.16.0 — 2026-07-12

Resolves three previously-deferred items (planned by a specialist squad).

- **`\middle`.** `\left( … \middle| … \right)` splits the body into segments and
  stretches every fence — left, each `\middle`, right — to the common height:
  set-builder `\left\{ x \mid P \right\}`, divided forms, conditional
  probability. New `.fenced(fences:segments:)` node; the no-`\middle` path still
  emits `.delimited` unchanged (zero regression).
- **`\operatorname*` limits.** A starred custom operator now stacks its scripts
  as under/over limits in display (`\operatorname*{Fix}_x`, `\operatorname*{ess\,sup}`),
  via a transparent `.limitsOperator` wrapper — no change to `.functionName`.
- **`\tag{…}` / `\tag*{…}`** (+ `\notag`/`\nonumber` no-ops). The tag is appended
  inline after a `\qquad` (`= r^2 \qquad (3.1)`). True flush-right / auto-numbering
  are host concerns (need the column width) and remain out of scope by design.

+8 tests (113 total). New public node cases `.fenced`, `.limitsOperator`.

## 0.15.0 — 2026-07-12

`\smallmatrix` (Batch 10) — script-size inline matrices, e.g.
`\left(\begin{smallmatrix} 1 & 0 \\ 0 & 1 \end{smallmatrix}\right)`. Stress
corpus grows to 66 equations (a "New notation" showcase page) at 100% native.

## 0.14.0 — 2026-07-12

General fractions & arrow variants (Batch 9).

- **`\genfrac{ldelim}{rdelim}{thickness}{style}{num}{denom}`** — the general
  fraction form: custom delimiters, rule on/off (`0pt` → no rule, e.g. a
  Legendre bracket `\genfrac{[}{]}{0pt}{}{n}{k}`), and forced style.
- **More stretchy arrows:** `\xLongrightarrow \xLongleftarrow \xhookrightarrow
  \xhookleftarrow \xmapsto \xrightharpoonup \xrightharpoondown \xleftharpoonup
  \xleftharpoondown \xleftrightarrow \xrightleftharpoons` — all take `{over}` /
  `[under]` labels (approximated to a stretchy left/right shaft).

+2 fixtures.

## 0.13.0 — 2026-07-12

Math-in-text and symbol fill-in (Batch 8).

- **Math inside `\text{}`.** `$…$` segments in a text body now render as math:
  `\text{$n$ terms}` gives an italic `n` then upright " terms";
  `\text{for all $\epsilon>0$}` embeds the inequality. (Closes the gap the
  stress-test surfaced where `$n$` rendered literally.)
- **More symbols:** `\land \lor \gets \colon \rightleftharpoons \triangleq
  \coloneqq \bigstar \dotsb \dotsc \dotsm` — with correct atom classes
  (`\colon` is punctuation, `\land`/`\lor` binary).

+1 test (109 total).

## 0.12.0 — 2026-07-12

Vector / over-arrows (Batch 7).

- **`\overrightarrow` / `\overleftarrow` / `\overleftrightarrow`** draw a
  stretchy arrow over the content, sized to its width — the vector notation
  (`\overrightarrow{AB}`), with correct single- or double-headed arrows.
- **`\underrightarrow` / `\underleftarrow` / `\underleftrightarrow`** draw the
  same beneath the content.

New `MathOverUnder` cases + a shared `horizontalArrow` stroke helper. +1
fixture.

## 0.11.0 — 2026-07-12

Spacing & box commands (Batch 6).

- **Named spaces:** `\thinspace \medspace \thickspace \negthinspace
  \negmedspace \negthickspace \enspace \>`.
- **Explicit lengths:** `\hspace{…}` / `\kern…` (em/pt) and `\mspace{…}` /
  `\mkern…` (mu), parsed braced or unbraced (`\mkern18mu`), converted to em.
- **`\smash`** (keep width, zero height/depth), **`\mathstrut`** (invisible
  paren-height strut), and the lap boxes **`\mathrlap` / `\mathllap` /
  `\mathclap`** (zero-width right/left/center overlap).

New `MathDecoration` cases `.smash`/`.rlap`/`.llap`/`.clap`. +5 tests
(108 total).

## 0.10.0 — 2026-07-12

Coverage expansion (Batch 5) — beyond the original roadmap.

- **Extended big operators.** `\iiint`, `\iiiint`, `\oiint`, `\oiiint`,
  `\coprod`, `\biguplus`, `\bigsqcup`, `\bigvee`, `\bigwedge`, `\bigoplus`,
  `\bigotimes`, `\bigodot` — all with the large-operator class (correct
  spacing) and display-limit stacking.
- **`\cancel` / `\bcancel` / `\xcancel`.** A diagonal strike (forward,
  backward, or both) across the content, drawn over the kept base — the
  fraction-cancellation notation.
- **`\not`.** Slashes the following atom, so `\not=` → ≠, `\not\in` → ∉,
  `\not\subset` → ⊄ — works over *any* relation, not just precomposed ones.

New `MathDecoration` cases `.cancel`/`.bcancel`/`.xcancel`/`.negation`. +3
golden fixtures.

## 0.9.0 — 2026-07-12

Structural `array` (Batch 4) — completes the four-batch typesetting roadmap.

- **Column specs** `{l c r}` are parsed into per-column alignment (previously
  read and discarded), so array columns align left / center / right.
- **Vertical rules** from `|` in the spec are drawn at the right boundaries,
  including edge rules (with outer padding) and multiple interior rules.
- **Horizontal rules** `\hline` (full width) and `\cline{i-j}` (column range)
  are drawn at their row boundaries.
- Together these give **augmented matrices** `[A | b]`, **bordered/truth
  tables**, and rule-separated systems — e.g.
  `\left[\begin{array}{ccc|c} … \end{array}\right]`.

Modeled as a new `ArraySpec` carried by a `.array(ArraySpec)` `MathMatrixStyle`
case, so `.matrix` layout stays shared. +6 tests (103 total); stress corpus
grows to 59 equations (a "Tables, arrays & linear systems" page) at 100% native.

## 0.8.0 — 2026-07-12

Deep TeX-fidelity batch (Batch 3) — the subtle metrics a typographer notices,
straight from Appendix G. Rendering changes; goldens regenerated and each
change verified by eye.

- **Binary/unary reclassification** (TeXbook p.170). A `Bin` atom with no left
  operand — at the start of a list or after Bin/Op/Rel/Open/Punct — is really a
  unary sign and becomes `Ord`; a `Bin` just left of a Rel/Close/Punct does
  too. So `x = -1` now sets a thick space after `=` and a tight unary minus,
  instead of medium space around the minus.
- **Cramped style.** Superscripts sit lower in cramped contexts — denominators,
  radicands, and subscripts — using the font's σ15 (`superscriptShiftUpCramped`).
  The exponent in `√(x²)` or a fraction's denominator now rides lower than in a
  numerator, matching TeX. Threaded through the engine like `\color`
  (numerator uncramped / denominator cramped; superscript uncramped / subscript
  cramped; radicand cramped).
- **TeX fraction shift-model.** Numerator and denominator are positioned by a
  nominal baseline shift (the font's `fractionNumeratorShiftUp` /
  `DenominatorShiftDown`, previously declared-but-unused), increased only as
  needed to keep a minimum gap from the rule — so a short `1` and a deep
  numerator share a stable baseline, instead of floating a fixed gap above the
  bar.
- **Axis-centered delimiters.** Auto-sized `\left…\right` fences are now
  centered on the math axis and sized to cover the body symmetrically about it
  (TeX measures each side from the axis), so an off-baseline body gets a fence
  tall enough on both ends. (Discrete size-variant selection is a follow-up —
  see COVERAGE.md.)

+11 tests (99 total). No new commands — pure fidelity.

## 0.7.0 — 2026-07-12

Common-commands batch (Batch 2 of the typesetting roadmap) — the constructs
real math reaches for, prioritized by the stress-corpus coverage audit.

- **`\pmod` / `\bmod` / `\pod`.** `a \equiv b \pmod{n}` renders `(mod n)` with
  the correct leading space; `\bmod` is a binary operator (`a \bmod n`). These
  were the *only* two commands the 46-equation stress corpus couldn't render —
  the corpus now renders **100% natively**.
- **`\dfrac` / `\tfrac` / `\dbinom` / `\tbinom` force their style.** A new
  `.mathStyle` node forces display or text style regardless of context, so
  `\dfrac` is large inline and `\tfrac` is small in a display block.
- **`\big \Big \bigg \Bigg` (+ `l`/`r`/`m`) actually enlarge** the delimiter to
  1.2 / 1.8 / 2.4 / 3.0× the base size, centered on the math axis, with the
  suffix selecting opening/closing/relation spacing (new `.bigDelimiter` node).
- **More `\left…\right` fences:** `\lceil \rceil \lfloor \rfloor`, `\uparrow`
  `\downarrow` `\Uparrow` `\Downarrow` `\updownarrow`, and `\backslash` now
  auto-size (previously fell back to `(`).
- **`\operatorname*`** parses correctly (renders upright; `*` limit-stacking is
  a follow-up) instead of degrading.

**Quantum-information corpus + fixtures.** Added an entanglement page to the
stress corpus (Bell/GHZ states, density matrices, the CHSH inequality with the
Tsirelson bound, Schmidt decomposition, von Neumann entropy) and promoted
several to golden fixtures. Corpus is now 55 equations at 100% native coverage.

+17 tests (94 total). New public node cases: `.mathStyle`, `.bigDelimiter`.

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
