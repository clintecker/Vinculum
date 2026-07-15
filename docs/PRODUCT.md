# Vinculum — Product Data

Structured product facts for downstream consumption (site design, marketing
copy, comparison pages). **Pure data**: no taglines, no visual/format
decisions. Every claim here is implemented and tested on `main`; deep
detail is linked per item.

---

## Identity

| Key | Value |
| --- | --- |
| Name | Vinculum |
| What it is | Native LaTeX math typesetting library for Apple platforms (layout engine also runs on Linux) |
| Version | 1.0.0+ (SemVer; see [CHANGELOG.md](../CHANGELOG.md)) |
| License (code) | MIT |
| License (bundled fonts) | GUST Font License (Latin Modern, TeX Gyre Termes/Pagella), SIL OFL (STIX Two) — redistribution/embedding permitted |
| Repo | https://github.com/clintecker/Vinculum |
| Install | SwiftPM: `.package(url: "https://github.com/clintecker/Vinculum.git", from: "1.0.0")` |
| Products | `VinculumRender` (Apple, everything), `VinculumLayout` (Foundation-only, Linux-capable parsing + layout) |
| Platforms | macOS 14+, iOS 17+, visionOS 1+, tvOS 17+; Linux (layout product) |
| Language/runtime | Swift 6, strict concurrency, `Sendable` API, zero third-party dependencies |
| Origin | Extracted from [Quoin](https://github.com/clintecker/quoin); sibling of [MermaidKit](https://github.com/clintecker/MermaidKit) |

## Target audiences

| Audience | Job to be done | Features that matter most (see groups below) |
| --- | --- | --- |
| AI/LLM chat-app developers | Render model responses containing `\(…\)`/`\[…\]`/`$…$` math natively in message views | G3 document pipeline, G6 fallback contract, G6 caching/perf, G5 accessibility |
| Notes / education / flashcard apps | Math inside user documents and study material, flowing with text | G3 (all surfaces), G2 command coverage, G4 fonts |
| Scientific/technical publishing tools | Print-grade typography matching TeX output | G1 typography, G4 fonts, G2 environments |
| Accessibility-focused teams | Math that VoiceOver reads meaningfully | G5 spoken math |
| Platform/infra engineers | Deterministic, testable, dependency-free rendering; server-side layout | G7 engineering, G3 custom-renderer seam |
| Editor/tool builders | Selection, inspection, source round-tripping over rendered math | G7 hit-testing, round-trip, diagnostics |

## Feature groups

### G1 — Typography quality (the font is the authority)

Everything the OpenType MATH standard defines, read from the live font at
load and used in layout. Deep detail: [ALGORITHM.md](ALGORITHM.md)
(rule-by-rule TeX Appendix G audit), [ARCHITECTURE.md](ARCHITECTURE.md).

| Feature | Specific |
| --- | --- |
| Font-parsed layout constants | All 56 `MathConstants` values (axis height, every shift/clearance/thickness, script scales) — no hardcoded metrics |
| TeX style lattice | display/text/script/scriptscript × cramped; style-correct constant pairs; spacing suppression in scripts; `\displaystyle` family |
| Italic correction | Per-glyph: superscript/subscript split (`f^2_3`), integral subscript tuck (`\int_a^b`), stacked-limit skew |
| Cut-in kerning | OpenType `MathKernInfo` staircases position scripts against the base glyph's corner profile (STIX Two ships data for 233 glyphs) |
| Accent placement | Per-glyph `topAccentAttachment` (better than TeX's `\skewchar`); `AccentBaseHeight` seat; wide accents from horizontal variant ladders; `\hat{f}^2` script promotion |
| Tall delimiters | Size-variant ladders → glyph assembly (end caps + extenders, constant stroke weight) → scaling, for every covered glyph |
| Radicals | The font's √ glyph via variants + assembly; font-true degree kerns and 60% raise |
| Display operators | Font's display-size variants at `DisplayOperatorMinHeight`, axis-centered; TeX Rule 13a limit clearances |
| Fence sizing | TeX's `\delimiterfactor`/`\delimitershortfall` formula |
| Inter-atom spacing | Real TeX atom classes (thin/medium/thick), suppressed in script styles |

Screenshots (CI-regenerated from current code, stable raw URLs):
- Real equations: https://raw.githubusercontent.com/clintecker/Vinculum/gallery/04-equations.png
- Tall fences/assembly: https://raw.githubusercontent.com/clintecker/Vinculum/gallery/02-structures.png
- Stress corpus page: https://raw.githubusercontent.com/clintecker/Vinculum/gallery/page-06.png

### G2 — LaTeX coverage

Deep detail: [COMMANDS.md](COMMANDS.md) (every supported command),
[COVERAGE.md](COVERAGE.md) (feature-by-feature with examples).

| Feature | Specific |
| --- | --- |
| Symbols | ~400 commands (Greek, operators, relations, arrows, delimiters, letterlike sets), each with its correct TeX atom class |
| Structures | Fractions (`\frac`/`\cfrac`/`\genfrac`/`\binom`), radicals with degree, scripts, accents, over/under constructs, boxes/rules/strikes, `\phantom` family, colors |
| Environments | All matrix variants, `cases`, `aligned`/`align`/`gather`/`split`/`multline`, `array` with column specs + `\hline`/`\cline`, `\substack`, `\tag` |
| Macros | Document-scoped `\newcommand`/`\renewcommand`/`\def` with `#1…#9`, recursion-capped |
| Direct Unicode | `∫ ∑ ≤ α` classed like their command spellings |
| Named operators | 37 function names; `\operatorname`/`\operatorname*` |
| Explicitly out of scope | mhchem, siunitx, `\href`, embedded HTML, `\begin{CD}` |

Screenshot: full command charts, e.g.
https://raw.githubusercontent.com/clintecker/Vinculum/gallery/sym-binary.png
(one chart per atom class on the [gallery branch](https://github.com/clintecker/Vinculum/tree/gallery)).

### G3 — Integration surfaces

Deep detail: [INTEGRATION.md](INTEGRATION.md), DocC catalog (Xcode ▸
Product ▸ Build Documentation).

| Surface | Call | Use case |
| --- | --- | --- |
| Document pipeline | `MathText.attributedString(from: wholeString)` | Prose with embedded math: markdown, chat, LLM output; all 4 delimiter styles; display math centered; document-scoped macros; unsupported math stays visible as source |
| Drop-in view | `VinculumLabel().latex = "…"` (AppKit/UIKit) | Standalone equations; alignment, insets, intrinsic size, opt-in inline errors |
| SwiftUI | `MathView("…").mathFont(.pagella)` | SwiftUI apps; modifiers for font/theme/size/inline |
| Attachment | `MathImageRenderer.attachmentString(latex:…)` | Rich-text composition; baseline-aligned `NSTextAttachment`; cached |
| Image + metadata | `MathImageRenderer.rendered(latex:…)` | Image, baseline descent, spoken description |
| Scene IR + custom renderer | `MathLayoutEngine.make(font:baseSize:)` → `MathScene` → `MathSceneRenderer.draw` or your own (glyph resolution via public `MathFont.ctFont(size:)`) | PDF pipelines, custom drawing, headless layout |

Code example (the LLM case):

```swift
textView.textStorage?.setAttributedString(
    MathText.attributedString(from: modelResponse))
```

### G4 — Fonts

Deep detail: [FONTS.md](FONTS.md).

| Feature | Specific |
| --- | --- |
| Bundled fonts | Latin Modern Math (default), TeX Gyre Termes Math, TeX Gyre Pagella Math, STIX Two Math |
| Bring-your-own | `MathFont(url:)` for any OTF with a MATH table; refuses fonts without one |
| Per-font truth | Constants/typography/variants/assemblies parsed per font at load; per-font render caching |
| Measured differences | STIX axis 0.258 vs LM 0.250; `DisplayOperatorMinHeight` 1.8 vs 1.3/1.3/1.5 em; STIX ships cut-in kern data |

Screenshots:
- Equation specimen, all four fonts: https://raw.githubusercontent.com/clintecker/Vinculum/gallery/07-fonts.png
- Glyph-by-glyph comparison grid: https://raw.githubusercontent.com/clintecker/Vinculum/gallery/08-font-glyphs.png

### G5 — Accessibility

| Feature | Specific |
| --- | --- |
| Spoken math | ClearSpeak-style utterances generated from the same tree that was typeset ("x equals the fraction negative b plus or minus the square root of b squared minus 4 a c, over 2 a") |
| Coverage | Fractions (incl. "1 half" simple forms), roots, scripts (squared/cubed/power), fences, matrices row-by-row, cases, binomials, accents, operators, ~80 symbol names |
| Where it applies | `VinculumLabel`, `MathView`, and every attachment image (math inside text views reads aloud) |
| API | `MathSpeech.describe(node)`; `RenderedMath.spokenDescription` |

### G6 — Reliability, safety, performance

| Feature | Specific |
| --- | --- |
| The fallback contract | Unsupported input degrades to named, visible source — never a broken half-render; `nil`/`isRendered` lets hosts keep their own fallback |
| Bounded parsing | Linear pre-scan + runtime depth counter; adversarial input (50 KB of `\sqrt\sqrt…`, 5,000 open braces) degrades instead of crashing |
| Fuzz-proven | Deterministic grammar/mutation/depth-attack corpora (4,000+ inputs): zero crashes, zero non-finite geometry |
| Adversarial font bytes | MATH-table parser is fully bounds-checked; crafted tables can't OOB or force multi-GB allocations |
| Caching | Content+theme+size+font keyed `NSCache`, count- and byte-bounded; negative caching for known-unsupported input |
| Measured performance | Cold parse→layout→raster ~0.3 ms; warm cache hit ~0.7 µs; headless layout ~40 µs (Apple silicon medians, enforced as test ceilings) |
| Concurrency | Swift 6 strict concurrency; immutable `Sendable` fonts/engines; audited lock discipline |

### G7 — Developer tooling

| Feature | Specific |
| --- | --- |
| Parse diagnostics with source ranges | `MathParser.diagnostics(for:)` → snippet + message + `Range<String.Index>` per issue (editor squiggles) |
| LaTeX round-trip | `MathNode.toLaTeX()`, render-equivalent and idempotent (copy-as-LaTeX, editing) |
| Hit-testing substrate | Opt-in `collectHitRegions` → `MathScene.hitTest(point)` → deepest subtree + rect + LaTeX (tap-to-inspect, selection) |
| Node model | Public `MathNode` tree with `children` traversal; `isFullySupported`, `unsupportedCommands` |
| DocC | Curated catalog (landing, Getting Started, Rendering Documents) |
| Demo app | `swift run VinculumDemo` — paste-and-render with font picker and dark toggle |

### G8 — Engineering & verification (trust signals)

| Feature | Specific |
| --- | --- |
| Test suite | 209 tests: headless geometry (Linux), golden-image regression with coverage ratchet, per-font canaries, fuzz, performance ceilings |
| CI matrix | Linux (headless layout), macOS (full suite), iOS simulator (runtime tests), gallery auto-publish |
| Golden discipline | ~95 pixel-pinned fixtures; a fixture that *starts* rendering fails CI until promoted (coverage can't silently change) |
| Ground truth | MATH-table parsing pinned against committed raw font bytes and fontTools |
| Docs | Rule-by-rule TeX Appendix G audit ([ALGORITHM.md](ALGORITHM.md)) stating Implemented/Partial/ABSENT honestly |

## Approach matrix (generic, no named competitors)

| Concern | WebView JS renderer | Server-side image | Vinculum |
| --- | --- | --- | --- |
| Runtime footprint | JS engine + web process per view | Network dependency | In-process, zero dependencies |
| Text integration (baseline, selection, line-breaking) | Snapshot only | Snapshot only | Native `NSTextAttachment` in the text system |
| Offline / privacy | Varies | No | Yes, fully on-device |
| Typography source | Web fonts + CSS | Varies | The font's own MATH table, per glyph |
| Macro-package breadth (mhchem, siunitx…) | Widest | Widest | Everyday-math subset by design |
| Deterministic/testable output | Engine-version dependent | Service dependent | Golden-pinned, headless-testable |
| Accessibility of math content | Varies | None (image) | Generated spoken math everywhere |

## Documentation index (link targets for any site)

| Module | Content |
| --- | --- |
| [README](../README.md) | Overview, quick start, support matrix, gallery |
| [FONTS.md](FONTS.md) | The four fonts, comparisons, BYO fonts, licensing |
| [COMMANDS.md](COMMANDS.md) | Every supported command |
| [COVERAGE.md](COVERAGE.md) | Feature-by-feature support with examples |
| [ALGORITHM.md](ALGORITHM.md) | TeX Appendix G audit |
| [ARCHITECTURE.md](ARCHITECTURE.md) | The layout/render split, seams, IR |
| [INTEGRATION.md](INTEGRATION.md) | Host integration guide |
| [ROADMAP.md](ROADMAP.md) / [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | History + open items (internal planning) |
| [CHANGELOG.md](../CHANGELOG.md) | Release history |
| DocC catalog | In-Xcode API reference |
| [Gallery branch](https://github.com/clintecker/Vinculum/tree/gallery) | Every screenshot above, CI-refreshed |

## Note on documentation modularization

Current modules are already single-topic. If further splitting is wanted
for a site, the natural seams are: FONTS.md → per-font pages;
COVERAGE.md → per-category pages (structures/environments/symbols);
ALGORITHM.md → per-rule anchors already exist (deep-linkable as-is).
Cross-linking is in place between README ↔ docs/* ↔ gallery.
