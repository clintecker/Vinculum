# Vinculum — Website Content Brief

A content and information-architecture brief for a Vinculum marketing + docs
site. **This is a brief, not a built site** — it specifies IA, per-page
purpose and content, the hero message, demo concepts, SEO, and CTAs. Hand it
to whoever builds the site (or to a landing-page skill).

**Audience:** iOS/macOS/visionOS developers evaluating how to render LaTeX
math in a native app — currently weighing a KaTeX/MathJax WebView, iosMath, or
rolling their own. Secondary: technical/education/note-taking app teams and
Swift open-source browsers.

**Tone:** confident, precise, developer-to-developer. Show real output and
real code. Never overclaim — the site's support claims must match
[COVERAGE.md](COVERAGE.md). Honesty is a differentiator here.

---

## Hero

**Headline:** *Native LaTeX math for Apple platforms. No WebView.*

**Sub-headline:** Real OpenType MATH glyphs, TeX-faithful metrics, and a
device-independent scene IR — a baseline-aligned `NSTextAttachment` in one
call. Swift 6, zero dependencies, builds on Linux.

**Primary CTA:** `Get started` → Installation.
**Secondary CTA:** `View on GitHub` → repo.

**Hero visual:** a beautifully rendered equation (the quadratic formula or
Euler's identity) shown *as an actual Vinculum render*, ideally beside its
three-line Swift call — "this LaTeX → this native glyph run." Toggle
light/dark to show the theme seam live.

### 3–4 headline value props (cards under the hero)

1. **No WebView, no JavaScript.** No web-content process, no HTML/CSS reflow,
   no bridge. Just CoreGraphics and a bundled font.
2. **Real TeX metrics.** Layout constants come from the font's OpenType MATH
   table (per Knuth, Appendix G) — not hand-tuned guesses. Latin Modern Math
   (Computer Modern) glyph shapes.
3. **Flows inline in TextKit.** Output is an `NSTextAttachment` that shares
   your text baseline, selection, and line-breaking — not a snapshot image
   floating in a box.
4. **Device-independent & testable.** Layout emits a `MathScene` IR (TeX's DVI
   in miniature) through an injected measurer seam, so geometry builds and
   unit-tests headless — on Linux, in CI.

---

## Sitemap / IA

```
/                     Home (hero, value props, mini demo, gallery teaser, comparison, CTA)
/gallery              Showcase: LaTeX ↔ native render, by category
/playground           Interactive "type LaTeX → see native render" demo
/docs                 Docs hub
  /docs/getting-started    Install + first attachment
  /docs/integration        Host-app guide (from INTEGRATION.md)
  /docs/coverage           Support matrix (from COVERAGE.md)
  /docs/architecture       Two-product / scene-IR / measurer seam (from ARCHITECTURE.md)
  /docs/api                API reference (generated)
/under-the-hood       The "Knuth & the MATH table" story
/compare              vs. KaTeX-in-WebView, vs. iosMath, vs. server-render
/changelog           Release history (from CHANGELOG.md)
```

Keep the top nav to five items: **Gallery · Playground · Docs · Under the
Hood · GitHub**.

---

## Page-by-page

### Home (`/`)

- Hero (above).
- Value-prop cards (above).
- **Mini live demo** — a small embedded version of the playground: one input,
  live render, a couple of preset chips (quadratic, sum, matrix).
- **Gallery teaser** — 6 rendered equations in a grid, "See the full gallery →".
- **Comparison strip** — condensed version of `/compare` (three columns:
  Vinculum / WebView / iosMath) with checkmarks.
- **Code sample** — the real `MathImageRenderer.attachmentString` call.
- **Closing CTA** — install snippet + GitHub button.

### Gallery (`/gallery`)

- **Purpose:** prove coverage and quality visually.
- Each entry: LaTeX source (monospace) beside its actual Vinculum render.
- Group by category matching the gallery posters: *Fractions, roots, scripts,
  operators* · *Delimiters, matrices, cases, aligned* · *Accents, binomials,
  braces, arrows, alphabets, color* · *Real-world equations* · *Macros* ·
  *Symbols & delimiters*.
- Include a "Real-world equations" row: quadratic, Euler, Schrödinger, Bayes,
  Maxwell, Riemann zeta — the ones already in `GalleryGenerator`.
- Source the images from the golden fixtures (`Tests/fixtures/math-golden/`)
  or generate posters via `VINCULUM_GALLERY_DIR`. **Show light *and* dark.**

### Playground (`/playground`)

- **Concept:** "Type LaTeX → see the native render." The single most
  persuasive page — it lets an evaluating developer test *their* equations.
- **Honest matrix twist:** when input contains an unsupported command, surface
  the *same* fallback the library gives — "⚠️ `\genfrac` not supported yet" —
  driven by the real coverage list. This turns the honesty policy into a trust
  feature.
- Preset chips (quadratic, sum with limits, pmatrix, `\newcommand` demo).
- Light/dark toggle and a base-size slider (mirrors `display`/`baseSize`).
- **Implementation note for the builder:** the library is native Swift, so a
  true in-browser render needs either (a) a small server that runs the Swift
  package and returns PNGs, (b) a pre-rendered corpus keyed by input with
  graceful "render on server" for novel input, or (c) a WASM build of
  VinculumLayout feeding a JS canvas renderer of the `MathScene` primitives
  (three cases: glyphs/rule/stroke — very tractable). Option (c) best embodies
  the "scene IR is portable" story. Do **not** fake it with KaTeX — that
  undermines the whole pitch.

### Docs hub (`/docs`)

- Card grid linking the four existing docs (Getting Started, Integration,
  Coverage, Architecture) + API reference + Changelog.
- Reuse the Markdown docs verbatim where possible; they're written for this.

### API reference (`/docs/api`)

- Generate from DocC / source. Organize by the stable public surface:
  - **VinculumLayout:** `MathParser` (`parse`, `isFullySupported`,
    `unsupportedCommands`), `MathNode` + companions, `MathLayoutEngine`,
    `MathScene` / `MathElement` / `MathColor` / `GlyphMetrics`,
    `MathTextMeasurer`, `MathMacros` / `MathMacroTable`.
  - **VinculumRender:** `MathImageRenderer`, `MathSceneRenderer`,
    `CoreTextMeasurer`, `MathTheme`, `PlatformColor`/`PlatformImage`.
- Flag pre-1.0 stability the way CONTRIBUTING.md does: entry points stable,
  `MathNode` model may reshape.

### Under the Hood (`/under-the-hood`)

- **Purpose:** the story page — earns credibility with the discerning reader
  (the audience most likely to write their own).
- **Narrative beats:**
  1. *The DVI split.* TeX separates "what to draw" from "how" — Vinculum's
     `MathScene` is that boundary, and it's why layout is headless/Linux.
  2. *Knuth's rule: read constants from the font.* Appendix G. The MATH table.
     Show the before/after from 0.4.0 — 35 hand-tuned multipliers replaced by
     the font's real numbers (axis 0.26→0.250, subscript drop 0.20→0.247, …).
  3. *Two kinds of numbers.* `MathConstants` (font-sourced) vs. `MathLayout`
     (Vinculum's own drawn shapes — the radical hook, brace arcs, arrowhead).
     "Zero unexplained numbers in the builders."
  4. *The atom-class spacing model.* Why `a+b` and `a=b` space differently —
     TeX's pair table, in `mu`.
  5. *The measurer seam.* One injected closure makes the whole engine testable
     without a screen.
- Diagrams: the pipeline flowchart (see ARCHITECTURE.md), a MATH-table
  constant callout, an atom-class spacing table.

### Compare (`/compare`)

- Three honest columns. Lead with when *not* to use Vinculum (need the full
  KaTeX macro universe → WebView). Credibility through candor.
- Rows: runtime (WebView/JS vs. native), inline text integration, determinism,
  Linux/headless testing, Swift 6 concurrency, LaTeX coverage breadth,
  platforms, dependencies.

---

## Interactive demo concept (detail)

**"See it render natively."** A split pane: LaTeX editor left, live render
right, with:

- Instant re-render on keystroke (debounced).
- A row of preset equations as clickable chips.
- Light/dark + base-size controls that map 1:1 to `mathTheme` / `baseSize`.
- **Honest fallback:** unsupported input shows the named-culprit warning the
  library actually emits, linking to the coverage page. This is the trust move
  — the demo tells the truth about limits.
- A "Copy the Swift" button that emits the exact `attachmentString` call for
  the current input.

Rendering strategy: prefer a **WASM build of VinculumLayout** + a tiny JS
renderer over the `MathScene`'s three primitives (glyphs/rule/stroke) — it
proves the portability claim and keeps the render authentic. Fallback: a
server that runs the package.

---

## Gallery / showcase concept

- A filterable grid: filter by category, toggle light/dark, click any tile to
  see its LaTeX source and copy it.
- Feature a "famous equations" band up top (Euler, Maxwell, Schrödinger,
  Bayes, zeta) as the emotional hook.
- Each tile is a real render — never a hand-drawn mockup. Verify tiles against
  the golden fixtures so the site can't drift from actual output.

---

## SEO

**Primary keywords:** native LaTeX math iOS, LaTeX math Swift, render math
SwiftUI, math typesetting Swift package, NSTextAttachment math, KaTeX
alternative iOS, iosMath alternative, MathJax without WebView, OpenType MATH
Swift, math rendering macOS.

**Long-tail / intent:** "render LaTeX in UITextView", "display math equations
SwiftUI native", "TeX math without JavaScript iOS", "Swift math layout Linux".

**On-page:** title + meta per page; the playground and gallery are the linkable
assets (developers share "try your equation" pages); mark up code samples;
ensure the comparison page ranks for "KaTeX vs native iOS."

**Content that earns links:** the Under-the-Hood MATH-table story (it's the
kind of deep-dive that gets posted to Hacker News / iOS Dev Weekly).

---

## Calls to action

- **Primary everywhere:** copy the SwiftPM one-liner
  (`.package(url: "…/Vinculum.git", from: "0.5.0")`) + "Get started".
- **Playground:** "Try your own equation."
- **Gallery:** "Copy this LaTeX."
- **Under the Hood / Compare:** "Read the architecture" → docs.
- **Global:** GitHub star button; link to Quoin and MermaidKit as proof of a
  maintained native-Swift family.

---

## Consistency guardrails (for whoever builds it)

- Every capability claim must match [COVERAGE.md](COVERAGE.md). If the site
  says a construct renders, it must render — verify against golden fixtures.
- Show ⚠️/❌ limitations openly (playground fallback, a "not yet" note on the
  coverage page). Candor is the brand.
- All rendered math on the site should be genuine Vinculum output, not
  KaTeX/MathJax standing in — using a competitor to render the marketing would
  be self-defeating.
- Font attribution: Latin Modern Math under the GUST Font License (OFL-style);
  code MIT. Keep a licenses page.
