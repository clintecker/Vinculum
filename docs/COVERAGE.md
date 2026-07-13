# Vinculum Coverage

The honest, code-checked support matrix for **Vinculum v0.23.0**. Every claim
here is verified against `MathSymbolTable.swift`, `MathParser.swift`, the
`Layout+*.swift` builders, and the golden fixtures in `Tests/fixtures/math-golden/`.

**How degradation works.** Vinculum never throws and never half-renders. An
unknown command becomes an `.unsupported` leaf; `MathParser.isFullySupported`
returns `false` for any tree that contains one; and `MathImageRenderer` returns
`nil` so the host shows its own fallback.
`MathParser.unsupportedCommands(in:limit:)` names the offending commands so a
fallback card can say *why*. `MathParser.parse` is total — the worst case is a
single `.unsupported(source)` leaf, never a crash.

Legend: ✅ native render · ⚠️ accepted but semantics not fully honored ·
❌ degrades to fallback.

**Scale (verified counts):** **404** symbol-table commands (`symbolTable`) +
**37** function-name operators (`functionNames`) — roughly ~400 commands in
total, across every TeX atom class, each carrying its correct inter-atom
spacing class.

---

## Fractions & stacks

| Command | Status | Example | Note |
| --- | :---: | --- | --- |
| `\frac` | ✅ | `\frac{a}{b}` | Ruled, axis-aligned |
| `\cfrac` | ✅ | `\cfrac{1}{1+\cfrac{1}{x}}` | Full-size continued fraction; optional `[l]`/`[r]` numerator alignment (amsmath default centered) |
| `\binom` | ✅ | `\binom{n}{k}` | Ruleless, paren-fenced |
| `\dfrac` / `\tfrac` | ✅ | `\dfrac{a}{b}` | Force display / text style regardless of ambient context |
| `\dbinom` / `\tbinom` | ✅ | `\dbinom{n}{k}` | Force display / text style |
| `\genfrac` | ✅ | `\genfrac{[}{]}{0pt}{}{n}{k}` | Custom left/right delims, rule on/off (`0pt` → no rule), forced style (`0`=display, `1/2/3`=text) |

```latex
\frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \qquad \cfrac{1}{1 + \cfrac{1}{1 + \cfrac{1}{x}}}
```

---

## Roots

| Command | Status | Example |
| --- | :---: | --- |
| `\sqrt` | ✅ | `\sqrt{2}` |
| `\sqrt[n]{}` | ✅ | `\sqrt[3]{x^2 + y^2}` |

---

## Scripts

| Feature | Status | Example |
| --- | :---: | --- |
| Superscript | ✅ | `x^2` |
| Subscript | ✅ | `x_i` |
| Both | ✅ | `a_{i,j}^{(k)}` |
| Nested | ✅ | `x^{2^{n}}` |
| Stacked limits (display) | ✅ | `\sum_{i=1}^{n}` — symbol operators stack in display |
| Primes as raised glyphs | ✅ | `f'`, `f''` render as raised, coalesced primes (`′`); `f'^2` merges the primes then the exponent |

Cramped style (denominators, radicands) lowers superscripts per TeX.

---

## Big operators (with display limits)

Operators whose limits **stack** above/below in display style and sit as
scripts inline:

```latex
\sum  \prod  \bigcup  \bigcap  \coprod  \biguplus  \bigsqcup
\bigvee  \bigwedge  \bigoplus  \bigotimes  \bigodot
```

Integral-class operators correctly keep their scripts **to the side** even in
display (TeX `\nolimits` behavior):

```latex
\int  \iint  \iiint  \iiiint  \oint  \oiint  \oiiint
```

Named function operators that stack their limit underneath in display style
(`\lim_{x\to0}`), matching TeX: `\lim \max \min \sup \inf \det \gcd \Pr \deg
\dim \ker \hom \arg \limsup \liminf \argmin \argmax`. All other function names
(`\sin \cos \log \ln …`) render upright with side scripts. `\mathop{…}` and
`\operatorname*{…}` also stack (see below).

---

## Symbols & Greek (~400 commands)

All carry correct TeX atom classes, so inter-atom spacing is real.

- **Greek** — lowercase `\alpha`…`\omega` plus variants (`\varepsilon
  \vartheta \varpi \varsigma \varphi \varkappa \varrho \digamma`), uppercase
  `\Gamma`…`\Omega`.
- **Binary operators** — `\pm \mp \times \div \cdot \ast \cup \cap \setminus
  \oplus \otimes \wedge \vee \circ \star \bullet \dagger \ddagger \sqcup
  \sqcap \uplus \odot \ominus \oslash \boxplus \boxtimes \triangleleft
  \triangleright \diamond \bigtriangleup \bigtriangledown \ltimes \rtimes
  \barwedge \veebar \boxdot \boxminus \circledast \dotplus \intercal
  \smallsetminus \Cap \Cup …`
- **Relations** — `\leq \geq \neq \equiv \approx \sim \simeq \cong \propto
  \subset \supset \subseteq \supseteq \in \ni \notin \prec \succ \preceq
  \succeq \models \vdash \dashv \asymp \doteq \sqsubseteq \gtrsim \lesssim
  \ll \gg \perp \parallel \mid \nmid \leqslant \geqslant \leqq \geqq \lll
  \ggg \vDash \Vdash \multimap …`, negated relations `\nleq \ngeq \nless
  \nsim \ncong \nsubseteq \nvdash \lneq \subsetneq …`, and arrows `\to
  \rightarrow \leftarrow \Rightarrow \Leftrightarrow \mapsto \hookrightarrow
  \longrightarrow \iff \implies \uparrow \twoheadrightarrow \rightarrowtail
  \curvearrowright \leftrightarrows \Rrightarrow \longmapsto \nrightarrow …`
  plus harpoons (`\leftharpoonup \rightharpoondown \leftrightharpoons …`).
- **Ordinary** — `\infty \partial \nabla \forall \exists \nexists \emptyset
  \varnothing \hbar \hslash \ell \Re \Im \aleph \beth \gimel \daleth \angle
  \measuredangle \sphericalangle \neg \top \bot \flat \sharp \natural
  \clubsuit \heartsuit \wp \complement \square \blacksquare \checkmark
  \lozenge \blacktriangle \imath \jmath \Bbbk \eth …` and dots `\dots
  \ldots \cdots \vdots \ddots \dotsb \dotsc`.
- **Standalone delimiters** (usable *outside* `\left…\right`): `\langle
  \rangle \lceil \rceil \lfloor \rfloor \lbrace \rbrace \lbrack \rbrack
  \lvert \rvert \lVert \rVert \vert \Vert \backslash`.
- **Escaped literals** — `\{ \} \| \$ \% \& \#`.
- **Direct Unicode** — typing `∫ ∑ ≤ α →` directly gets the same atom class
  its command spelling would, so spacing and operator limits still work.

For the exhaustive command-by-command index see [COMMANDS.md](COMMANDS.md); for the raw set see `MathSymbolTable.swift` (`symbolTable`, 404 entries) and
the `functionNames` set (37 entries).

---

## Atom-class overrides

Force the inter-atom spacing class of a subexpression:

| Command | Forces class | Note |
| --- | --- | --- |
| `\mathbin` | binary | `a \mathbin{\star} b` |
| `\mathrel` | relation | |
| `\mathop` | large operator | **Also takes stacked display limits** (`\mathop{\oplus}\limits_{i}`) |
| `\mathord` / `\mathinner` | ordinary | |
| `\mathopen` | opening | |
| `\mathclose` | closing | |
| `\mathpunct` | punctuation | |

All ✅.

---

## Matrices & environments

| Environment | Status | Fences / alignment |
| --- | :---: | --- |
| `matrix` | ✅ | none, centered |
| `pmatrix` | ✅ | `( )` |
| `bmatrix` | ✅ | `[ ]` |
| `Bmatrix` | ✅ | `{ }` |
| `vmatrix` | ✅ | `\| \|` |
| `Vmatrix` | ✅ | `‖ ‖` |
| `smallmatrix` | ✅ | script-size grid, no fences |
| `cases` | ✅ | `{`, left-aligned columns |
| `aligned` / `align` / `alignat` / `alignedat` / `split` / `gather` / `gathered` / `multline` | ✅ | alignment at `&` |
| `substack` | ✅ | tight centered stack (script size) |
| `array` | ✅ | `{l c r \| c}` per-column alignment + `\|` vertical rules + `\hline` / `\cline{i-j}` — augmented matrices `[A\|b]`, bordered/truth tables |

- `array` draws `\hline` / `\cline{a-b}` and `|` column rules. In the other
  environments those tokens are consumed and ignored (they don't flip the grid
  to a fallback).
- **`alignat{n}` / `alignedat{n}`**: the `{n}` column count is consumed
  correctly (it used to leak into the first cell).
- **Starred forms** `align*`, `pmatrix*`, `matrix*` etc. are accepted. A
  trailing column-alignment bracket (`pmatrix*[r]`, `matrix*[l]`) applies its
  alignment uniformly to every column.

```latex
\begin{pmatrix} a & b \\ c & d \end{pmatrix}
\begin{cases} x^2 & x \ge 0 \\ -x & x < 0 \end{cases}
\begin{aligned} a &= b + c \\ &= d + e \end{aligned}
\begin{array}{c|c} A & b \\ \hline 1 & 2 \end{array}
```

---

## Math alphabets

Mapped to Unicode Mathematical Alphanumeric Symbols; CoreText resolves them
through STIX Two / Apple Symbols (no bundled font needed). The pre-Unicode
"Letterlike Symbols" holes (ℝ ℂ ℋ ℯ …) are handled by exception tables.

| Command | Alphabet | Digits? | Notes |
| --- | --- | :---: | --- |
| `\mathbb` | blackboard 𝔸 | ✅ | Holes: ℂ ℍ ℕ ℙ ℚ ℝ ℤ |
| `\mathcal` / `\mathscr` | script 𝒜 | ❌ | Holes: ℬ ℰ ℱ ℋ ℐ ℒ ℳ ℛ ℯ ℊ ℴ |
| `\mathfrak` | fraktur 𝔞 | ❌ | Holes: ℭ ℌ ℑ ℜ ℨ |
| `\mathsf` | sans-serif 𝖠 | ✅ | |
| `\mathtt` | monospace 𝙰 | ✅ | |
| `\mathbf` | bold | — | Rendered with a **bold system font**, not a codepoint |
| `\boldsymbol` / `\bm` | bold-italic 𝑨 | bold digits | Codepoint-mapped |
| `\pmb` | ≈ bold | — | "Poor-man bold" approximated as `\mathbf` |

```latex
\mathbb{R} \subset \mathbb{C}, \quad \mathcal{L}(f), \quad \mathfrak{g}, \quad \mathsf{AB}\,\mathtt{cd}
```

---

## Accents

| Kind | Commands | Status |
| --- | --- | :---: |
| Point accents | `\hat \check \tilde \bar \vec \dot \ddot \breve \mathring \acute \grave` | ✅ |
| Stretchy | `\widehat \widetilde \widecheck` | ✅ (grow toward base width, clamped) |
| Rules | `\overline \underline` | ✅ (drawn rule, not a glyph) |

Point accents use ink extents (not the loose typographic box) for placement.

```latex
\hat{x} \quad \vec{v} \quad \bar{z} \quad \widehat{ABC} \quad \widecheck{f} \quad \overline{AB}
```

---

## Over/under constructs

| Command | Status | Example |
| --- | :---: | --- |
| `\overset` / `\underset` / `\stackrel` | ✅ | `\stackrel{?}{=}` |
| `\overbrace{}^{label}` | ✅ | `\overbrace{a+b+c}^{\text{sum}}` |
| `\underbrace{}_{label}` | ✅ | `\underbrace{1+\cdots+n}_{n\text{ terms}}` |
| `\overbracket` / `\underbracket` | ✅ | Square-bracket brace with vertical end tines |
| `\overparen` / `\underparen` | ✅ | Parenthesis-style arc |
| `\overrightarrow` / `\overleftarrow` / `\overleftrightarrow` | ✅ | Vector arrows over the content: `\overrightarrow{AB}` |
| `\underrightarrow` / `\underleftarrow` / `\underleftrightarrow` | ✅ | Arrows drawn under the content |

Braces/brackets/parens are drawn as hand-stroked paths; arrows are a stretchy
shaft plus a drawn head sized to fit the label.

---

## Extensible ("stretchy") arrows

`\xrightarrow[under]{over}` / `\xleftarrow[under]{over}`: an arrow shaft that
stretches to the wider of its optional `[under]` and `{over}` labels.

| Command | Status | Note |
| --- | :---: | --- |
| `\xrightarrow` / `\xleftarrow` | ✅ | Right / left shaft with head |
| `\xLongrightarrow` / `\xLongleftarrow` / `\xhookrightarrow` / `\xhookleftarrow` / `\xmapsto` / `\xrightharpoonup` / `\xrightharpoondown` / `\xleftharpoonup` / `\xleftharpoondown` / `\xleftrightarrow` / `\xrightleftharpoons` | ⚠️ | **Accepted and stretched, but all approximate to a plain left/right shaft** — the hook / harpoon / mapsto / double-line arrowheads are not drawn distinctly |

```latex
A \xrightarrow{f} B \xrightarrow[g]{} C
```

---

## Decorations, boxes & color

| Command | Status | Example | Note |
| --- | :---: | --- | --- |
| `\boxed` / `\fbox` | ✅ | `\boxed{E = mc^2}` | Stroked frame with padding |
| `\colorbox{bg}{…}` | ✅ | `\colorbox{yellow}{x}` | Filled background rectangle |
| `\fcolorbox{border}{bg}{…}` | ✅ | `\fcolorbox{red}{yellow}{x}` | Filled background + stroked border |
| `\rule{w}{h}` | ✅ | `\rule{2em}{0.4pt}` | Solid filled rectangle; optional `[raise]` consumed |
| `\raisebox{s}{…}` | ✅ | `\raisebox{2pt}{x}` | Vertical shift of the content |
| `\cancel` / `\bcancel` / `\xcancel` | ✅ | `\cancel{x}` | Forward / backward / crossed strike over the base |
| `\cancelto{t}{expr}` | ✅ | `\cancelto{0}{x}` | Strike `expr`, `t` as a raised label |
| `\not` | ✅ | `\not=`, `\not\subset` | Steep slash negating the following atom |
| `\phantom` | ✅ | `\phantom{x}` | Reserves full box |
| `\hphantom` / `\vphantom` | ✅ | `\vphantom{\int}` | Reserves width / height only |
| `\smash` | ✅ | `\smash{\int}` | Keeps width, zero height/depth (`[t]`/`[b]` treated as plain smash) |
| `\mathstrut` | ✅ | | Invisible paren-height strut |
| `\mathrlap` / `\mathllap` / `\mathclap` | ✅ | | Zero-width right / left / center overlap |
| `\color{name}{body}` | ✅ | `\color{red}{x}` | Braced two-argument (localized) form |
| `\color{name}` | ✅ | `\color{red} x + y` | **Stateful** form — applies to the rest of the current group |
| `\textcolor{name}{body}` | ✅ | `\textcolor{#2244cc}{y}` | Named palette or `#rrggbb` |

Named colors: `red blue green orange purple teal yellow pink magenta brown
gray grey cyan black white`, plus any `#rrggbb` hex. Scenes with explicit color
set `MathScene.hasExplicitColor`.

```latex
\boxed{E = mc^2} \quad \cancel{x} \quad \color{blue}{a + b} \quad \fcolorbox{teal}{yellow}{k}
```

---

## Text & operator names

| Command | Status | Note |
| --- | :---: | --- |
| `\text` / `\textrm` | ✅ | Upright run; interior spaces preserved (`\text{if } x`); nested braces kept |
| `\mathrm` | ✅ | Upright |
| `\operatorname` | ✅ | Upright custom operator |
| `\operatorname*{…}` | ✅ | Upright **and stacks its limits** in display style (`\operatorname*{argmax}_{x}`) |
| Named functions | ✅ | `\sin \cos \tan \log \ln \exp \lim \det \gcd \max \min …` (37 total) |
| Math inside `\text` | ✅ | `\text{$n$ terms}` — `$…$` spans render as math (italic `n`, upright " terms") |
| `\pmod` / `\bmod` / `\pod` | ✅ | `a \equiv b \pmod{n}` → `(mod n)`; `\bmod` is a binary operator |

---

## Equation tags

| Command | Status | Note |
| --- | :---: | --- |
| `\tag{…}` | ✅ | Appended inline as `body \qquad (tag)` |
| `\tag*{…}` | ✅ | Appended inline without parentheses |
| `\notag` / `\nonumber` | ✅ | No-op (Vinculum does no auto-numbering to suppress) |

True flush-right tag placement is a host concern (it needs the column width);
Vinculum places the tag inline after the body.

```latex
E = mc^2 \tag{1} \qquad F = ma \tag*{Newton}
```

---

## Spacing

| Command | Width |
| --- | --- |
| `\,` / `\thinspace` | thin (3/18 em) |
| `\:` / `\>` / `\medspace` | medium (4/18 em) |
| `\;` / `\thickspace` | thick (5/18 em) |
| `\!` / `\negthinspace` | negative thin (−3/18 em) |
| `\negmedspace` / `\negthickspace` | −4/18 · −5/18 em |
| `\ ` (backslash-space) | 6/18 em |
| `\enspace` | 1/2 em |
| `\quad` / `\qquad` | 1 em · 2 em |
| `\hspace{…}` / `\kern…` | explicit length, default em/pt |
| `\mspace{…}` / `\mkern…` | explicit length, default mu (braced or unbraced) |

Length units understood: `em`, `mu` (1/18 em), `ex` (≈0.43 em), `pt` (1/10 em);
`cm`/`mm`/`in` are approximated. Negative and signed lengths are accepted.

---

## Delimiter sizing

| Command | Status | Note |
| --- | :---: | --- |
| `\left … \right` | ✅ | Auto-sizes fences to the body: `( ) [ ]`, `\{ \}`, `\| \langle \rangle \lvert \rvert \lVert \Vert`, `\lceil \rceil \lfloor \rfloor`, arrows (`\uparrow \downarrow \updownarrow \Uparrow \Downarrow`), `\backslash`, and `\left.`/`\right.` for a null fence |
| `\middle` | ✅ | `\left( \frac{a}{b} \,\middle\|\, c \right)` — interior fence stretched to the same height, splitting the body into segments |
| `\big \Big \bigg \Bigg` (+`l`/`r`/`m`) | ✅ | Enlarges the delimiter to 1.2 / 1.8 / 2.4 / 3.0× base size; the `l`/`r`/`m` suffix sets opening / closing / relation spacing |

**MATH-table size variants.** For clearly-tall fences, Vinculum prefers the
bundled Latin Modern Math font's purpose-drawn size-variant glyphs (constant
stroke weight) over continuous point-scaling. This variant path is **gated to
`( ) [ ] { }`** (verified to map correctly); every other delimiter — and every
fence taller than the largest available variant — falls back to smooth
point-scaling, which very slightly fattens strokes on extreme heights.

```latex
\left( \sum_{k=0}^{n} a_k \right) \qquad
\left\{\, x \in \mathbb{R} \;\middle|\; x > 0 \,\right\}
```

---

## Macros

Document-scoped `\newcommand` / `\renewcommand` / `\def`, expanded before
typesetting. Supports `#1`…`#9` parameters, an optional `[argc]`, and a hard
recursion/budget cap so a self-referential macro degrades instead of hanging.

```latex
\newcommand{\abs}[1]{\left|#1\right|} \abs{x} + \abs{y} \ge \abs{x + y}
\newcommand{\R}{\mathbb{R}}\newcommand{\inner}[2]{\langle #1, #2 \rangle} \inner{u}{v} \in \R
```

`MathMacros.collectDefinitions(from:)` scans a whole document's math segments so
a definition in one block applies everywhere; later definitions win (matching
`\renewcommand`).

---

## Not yet supported (roadmap gaps)

Honest list of what degrades to a source fallback (or is only partially
honored):

- **Extensible delimiter assembly** — arbitrarily-tall fences beyond the
  font's largest discrete size variant are point-scaled rather than assembled
  from repeatable segments, so a very tall fence has slightly heavy strokes.
- **Remaining variant delimiters** — `⟨ ⟩ ‖ ⌈ ⌉ ⌊ ⌋` are not yet on the
  verified MATH-variant path and fall back to scaling (the `( ) [ ] { }` set
  uses true variants).
- **Extensible-arrow variety** — the `\x…arrow` hook / harpoon / mapsto /
  double-line heads render as a plain shaft (⚠️ above).
- `\sideset`, `\mathchoice`, `\DeclareMathOperator` (needs a macro-table
  branch) — ❌.
- `\utilde` and harpoon accents (`\overrightharpoon`, `\overleftharpoon`, …) — ❌.
- `\begin{CD}` (commutative diagrams — a diagram problem, out of scope).
- **Out of scope by design:** `\href`, `\includegraphics`, mhchem `\ce`,
  siunitx, `\verb`.
- `\mathcal` / `\mathfrak` / `\mathscr` render **letters only** (no digit
  variants exist in Unicode).
- `\mathbf` uses a bold **system font**, not a Mathematical-Alphanumeric
  codepoint.

If you need one of these, it's a good first contribution — see the "add a
command" walkthrough in [ARCHITECTURE.md](ARCHITECTURE.md).
