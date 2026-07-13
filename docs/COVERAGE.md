# Vinculum Coverage

The honest, code-checked support matrix. Every claim here is verified against
`MathSymbolTable.swift`, `MathParser.swift`, and the `Layout+*.swift` builders.

**How degradation works.** Vinculum never throws and never half-renders. An
unknown command becomes an `.unsupported` leaf; `MathParser.isFullySupported`
returns `false` for any tree containing one; and `MathImageRenderer` returns
`nil` so the host shows its own fallback.
`MathParser.unsupportedCommands(in:)` names the offending commands so a
fallback card can say *why*.

Legend: ✅ native render · ⚠️ accepted but semantics not fully honored ·
❌ degrades to fallback.

---

## Fractions & stacks

| Command | Status | Example | Note |
| --- | :---: | --- | --- |
| `\frac` | ✅ | `\frac{a}{b}` | Ruled, axis-aligned |
| `\cfrac` | ✅ | `\cfrac{1}{1+\cfrac{1}{x}}` | Renders as a plain nested fraction (no cfrac left/right alignment) |
| `\binom` | ✅ | `\binom{n}{k}` | Ruleless, paren-fenced |
| `\dfrac` / `\tfrac` | ⚠️ | `\dfrac{a}{b}` | Parsed, but the forced display/text style is **ignored** — same as `\frac` |
| `\dbinom` / `\tbinom` | ⚠️ | `\dbinom{n}{k}` | Same as `\binom`; forced size ignored |
| `\genfrac` | ❌ | `\genfrac{(}{)}{0pt}{}{n}{k}` | The general 5-argument form is **not parsed** (the `genfrac` *node* exists internally, but only `\binom` produces it) |

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
| Primes as raised glyphs | ❌ | `f'` — `'` stays an ordinary apostrophe, not a raised prime (use `f^{\prime}`) |

---

## Big operators (with display limits)

Supported operators — limits stack above/below in display style, sit as
scripts inline:

```latex
\sum  \prod  \int  \iint  \oint  \bigcup  \bigcap
```

Named function operators — `\lim`, `\max`, `\min`, `\sup`, `\inf`, `\det`,
`\gcd`, `\limsup`, `\liminf`, `\argmin`, `\argmax` — render upright, but ⚠️
their limit currently sits at the lower-right (like a subscript) rather than
*underneath* in display style. TeX puts `\lim_{x\to0}` under the operator;
Vinculum doesn't yet (they parse to function names, which the stacked-limits
path doesn't cover). On the roadmap; see the "Not yet" section.

❌ Not in the table (degrade): `\iiint`, `\bigsqcup`, `\bigvee`, `\bigwedge`,
`\bigoplus`, `\bigotimes`, `\bigodot`, `\coprod`.

---

## Symbols & Greek (~200 commands)

All carry correct TeX atom classes, so inter-atom spacing is real.

- **Greek** — lowercase `\alpha`…`\omega` (plus `\varepsilon \vartheta
  \varpi \varsigma \varphi`), uppercase `\Gamma`…`\Omega`.
- **Binary operators** — `\pm \mp \times \div \cdot \ast \cup \cap
  \setminus \oplus \otimes \wedge \vee \circ \star \bullet \dagger \ddagger
  \sqcup \sqcap \uplus \odot \ominus \oslash \boxplus \boxtimes
  \triangleleft \triangleright \diamond \bigtriangleup \bigtriangledown …`
- **Relations** — `\leq \geq \neq \equiv \approx \sim \simeq \cong \propto
  \subset \supset \subseteq \supseteq \in \ni \notin \prec \succ \preceq
  \succeq \models \vdash \dashv \asymp \doteq \sqsubseteq \gtrsim \lesssim
  \ll \gg \perp \parallel \mid \nmid …` and arrows `\to \rightarrow
  \leftarrow \Rightarrow \Leftrightarrow \mapsto \hookrightarrow
  \longrightarrow \iff \implies \uparrow \downarrow …`
- **Ordinary** — `\infty \partial \nabla \forall \exists \nexists
  \emptyset \varnothing \hbar \ell \Re \Im \aleph \angle \neg \top \bot
  \flat \sharp \natural \clubsuit \heartsuit \wp \complement \square
  \blacksquare \checkmark \imath \jmath …` and dots `\dots \ldots \cdots
  \vdots \ddots`.
- **Standalone delimiters** (usable *outside* `\left…\right`): `\langle
  \rangle \lceil \rceil \lfloor \rfloor \lbrace \rbrace \lvert \rvert
  \lVert \rVert \vert \Vert \backslash`.
- **Direct Unicode** — typing `∫ ∑ ≤ α →` directly gets the same atom class
  its command spelling would, so spacing and operator limits still work.

For the exact set, see `MathSymbolTable.swift` (`symbolTable`) and the
function-name set (`functionNames`).

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
| `cases` | ✅ | `{`, left-aligned columns |
| `aligned` / `align` / `alignat` / `split` / `gather` | ✅ | alignment at `&` |
| `substack` | ✅ | tight centered stack (script size) |
| `array` | ⚠️ | Renders as a **bare centered grid**; the `{ccc}` column spec is consumed and ignored |

Row/column rules `\hline`, `\hdashline`, `\cline{a-b}` are **consumed and
ignored** (so they don't flip the whole grid to a fallback), but no rule is
drawn. Starred forms (`align*`, `pmatrix*`) are accepted (the `*` is
stripped).

```latex
\begin{pmatrix} a & b \\ c & d \end{pmatrix}
\begin{cases} x^2 & x \ge 0 \\ -x & x < 0 \end{cases}
\begin{aligned} a &= b + c \\ &= d + e \end{aligned}
```

---

## Math alphabets

Mapped to Unicode Mathematical Alphanumeric Symbols; CoreText resolves them
through STIX Two / Apple Symbols. The pre-Unicode "Letterlike Symbols" holes
(ℝ ℂ ℋ ℯ …) are handled by exception tables.

| Command | Alphabet | Digits? | Notes |
| --- | --- | :---: | --- |
| `\mathbb` | blackboard 𝔸 | ✅ | Holes: ℂ ℍ ℕ ℙ ℚ ℝ ℤ |
| `\mathcal` / `\mathscr` | script 𝒜 | ❌ | Holes: ℬ ℰ ℱ ℋ ℐ ℒ ℳ ℛ ℯ ℊ ℴ |
| `\mathfrak` | fraktur 𝔞 | ❌ | Holes: ℭ ℌ ℑ ℜ ℨ |
| `\mathsf` | sans-serif 𝖠 | ✅ | |
| `\mathtt` | monospace 𝙰 | ✅ | |
| `\mathbf` | bold | — | Rendered with a **bold system font**, not a codepoint |
| `\boldsymbol` / `\bm` | bold-italic 𝑨 | bold digits | Codepoint-mapped |

```latex
\mathbb{R} \subset \mathbb{C}, \quad \mathcal{L}(f), \quad \mathfrak{g}, \quad \mathsf{AB}\,\mathtt{cd}
```

---

## Accents

| Kind | Commands | Status |
| --- | --- | :---: |
| Point accents | `\hat \check \tilde \bar \vec \dot \ddot \breve \mathring \acute \grave` | ✅ |
| Stretchy | `\widehat \widetilde` | ✅ (grow toward base width, clamped) |
| Rules | `\overline \underline` | ✅ (drawn rule, not a glyph) |

Point accents use ink extents (not the loose typographic box) for placement.

```latex
\hat{x} \quad \vec{v} \quad \bar{z} \quad \widehat{ABC} \quad \overline{AB}
```

---

## Over/under constructs

| Command | Status | Example |
| --- | :---: | --- |
| `\overset` / `\underset` / `\stackrel` | ✅ | `\stackrel{?}{=}` |
| `\overbrace{}^{label}` | ✅ | `\overbrace{a+b+c}^{\text{sum}}` |
| `\underbrace{}_{label}` | ✅ | `\underbrace{1+\cdots+n}_{n\text{ terms}}` |
| `\xrightarrow` / `\xleftarrow` | ✅ | `A \xrightarrow{f} B \xrightarrow[g]{} C` |

Braces are drawn as hand-stroked quadratic arcs; arrows are a stretchy rule
plus a drawn head sized to fit the label.

---

## Decorations & color

| Command | Status | Example | Note |
| --- | :---: | --- | --- |
| `\boxed` | ✅ | `\boxed{E = mc^2}` | Stroked frame with padding |
| `\phantom` | ✅ | `\phantom{x}` | Reserves full box |
| `\hphantom` / `\vphantom` | ✅ | `\vphantom{\int}` | Reserves width / height only |
| `\color{name}{body}` | ✅ | `\color{red}{x}` | **Braced two-argument form only** |
| `\textcolor{name}{body}` | ✅ | `\textcolor{#2244cc}{y}` | Named palette or `#rrggbb` |

Named colors: `red blue green orange purple teal yellow pink magenta brown
gray grey cyan black white`. The **stateful** `\color{name}` (applies to the
rest of the group) form is ❌ **not** supported — use the braced form.

---

## Text & operator names

| Command | Status | Note |
| --- | :---: | --- |
| `\text` / `\textrm` | ✅ | Upright run |
| `\mathrm` | ✅ | Upright |
| `\operatorname` | ✅ | Upright custom operator |
| Named functions | ✅ | `\sin \cos \tan \log \ln \exp \lim \det \gcd \max \min …` |
| Spaces inside `\text{…}` | ❌ | The math tokenizer drops literal spaces — use `\ ` (backslash-space): `\text{if\ } x` |
| `\operatorname*{…}` | ❌ | The `*` becomes a stray operator; limit-taking form not honored |
| `\pmod` / `\bmod` | ❌ | `\pmod` degrades; `mod` alone is a function name |

---

## Spacing

| Command | Width |
| --- | --- |
| `\,` | thin (3/18 em) |
| `\:` | medium (4/18 em) |
| `\;` | thick (5/18 em) |
| `\!` | negative thin (−3/18 em) |
| `\ ` (backslash-space) | 6/18 em |
| `\quad` | 1 em |
| `\qquad` | 2 em |

---

## Delimiter sizing

| Command | Status | Note |
| --- | :---: | --- |
| `\left … \right` | ✅ | Auto-sizes fences to the body: `( ) [ ]`, `\{ \}`, `\| \langle \rangle \lvert \rvert \lVert \Vert`, and `\left.`/`\right.` for a null fence. (`\lceil \rceil \lfloor \rfloor` work standalone but are **not** recognized as `\left`/`\right` fences — they fall back to `(`) |
| `\big \Big \bigg \Bigg` (+`l`/`r`/`m`) | ⚠️ | Parsed **transparently** — the following delimiter renders at normal size, not enlarged |

---

## Macros

Document-scoped `\newcommand` / `\renewcommand` / `\def`, expanded before
typesetting. Supports `#1`…`#9` parameters, an optional `[argc]`, and a hard
recursion/budget cap so a self-referential macro degrades instead of hanging.

```latex
\newcommand{\abs}[1]{\left|#1\right|} \abs{x} + \abs{y} \ge \abs{x + y}
\newcommand{\R}{\mathbb{R}}\newcommand{\inner}[2]{\langle #1, #2 \rangle} \inner{u}{v} \in \R
```

`MathMacros.collectDefinitions(from:)` scans a whole document's math segments
so a definition in one block applies everywhere; later definitions win
(matching `\renewcommand`).

---

## Not yet supported (roadmap gaps)

Honest list of what degrades to a source fallback (or is silently ignored):

- **`\genfrac`** — the general 5-argument fraction form is not parsed.
- **Forced fraction/binom style** — `\dfrac \tfrac \dbinom \tbinom` render but
  ignore the forced display/text style.
- **Explicit delimiter sizing** — `\big \Big \bigg \Bigg` (and `l`/`r`/`m`
  variants) are transparent; the fence is not enlarged.
- **True `\cfrac` alignment** — renders as a plain nested fraction.
- **Spaces inside `\text{}`** — dropped by the math tokenizer (use `\ `).
- **Primes as raised glyphs** — `'` is an ordinary apostrophe; use `^{\prime}`.
- **`array` column specs & rules** — grid renders centered; `{ccc}` and
  `\hline`/`\cline` are consumed but not applied.
- **`\pmod` / `\bmod`**, **`\operatorname*`**, **`\cancel`**, **`\not`**.
- **Cramped-style script lowering** — the cramped style is not modeled.
- **Additional big operators** — `\iiint \coprod \bigsqcup \bigvee \bigwedge
  \bigoplus \bigotimes \bigodot` are not in the symbol table.

If you need one of these, it's a good first contribution — see the "add a
command" walkthrough in [ARCHITECTURE.md](ARCHITECTURE.md).
