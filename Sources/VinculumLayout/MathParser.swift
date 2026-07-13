import Foundation

public enum MathParser {

    /// Parser recursion depth tracks brace / environment nesting; adversarial
    /// input ("{{{{…" ×10k) would otherwise overflow the stack. Past this
    /// bound the whole expression degrades to styled source (PRD rule:
    /// unknown input degrades, never crashes).
    static let maxNestingDepth = 64

    /// Parses a LaTeX math string. Unknown commands become `.unsupported`
    /// leaves; the parse itself never fails.
    public static func parse(_ latex: String) -> MathNode {
        // Linear pre-scan bounds recursion before it starts: parse recursion
        // depth ≤ max brace nesting + \begin count.
        var depth = 0, maxDepth = 0
        for ch in latex {
            if ch == "{" { depth += 1; maxDepth = max(maxDepth, depth) }
            if ch == "}" { depth = max(0, depth - 1) }
        }
        let begins = latex.components(separatedBy: "\\begin").count - 1
        guard maxDepth <= maxNestingDepth, begins <= maxNestingDepth else {
            return .unsupported(latex)
        }

        var tokens = Tokenizer(latex).tokenize()[...]
        let nodes = parseRow(&tokens, until: nil)
        return nodes.count == 1 ? nodes[0] : .row(nodes)
    }

    // MARK: - Parser

    private static func parseRow(_ tokens: inout ArraySlice<Token>, until terminator: Token?) -> [MathNode] {
        var nodes: [MathNode] = []
        while let token = tokens.first {
            if let terminator, token == terminator {
                tokens.removeFirst()
                break
            }
            guard let node = parseAtom(&tokens) else { continue }
            nodes.append(attachScriptsAndPrimes(node, &tokens))
        }
        return nodes
    }

    /// One atom: a group, a command, or a single character.
    private static func parseAtom(_ tokens: inout ArraySlice<Token>) -> MathNode? {
        guard let token = tokens.first else { return nil }
        tokens.removeFirst()

        switch token {
        case .groupOpen:
            let nodes = parseRow(&tokens, until: .groupClose)
            return nodes.count == 1 ? nodes[0] : .row(nodes)

        case .groupClose:
            return nil // stray brace: ignore

        case .superscriptMark, .subscriptMark:
            return nil // handled by caller; stray marks ignored

        case .character(let ch):
            return characterNode(ch)

        case .command(let name):
            return commandNode(name, &tokens)

        case .rawText(let s):
            // Only appears right after a text command (consumed there); a stray
            // one degrades to upright text rather than vanishing.
            return .functionName(s)
        }
    }

    /// Attaches trailing primes (`f'` → `f^{′}`) and any `^`/`_` scripts to a
    /// just-parsed atom. Shared by `parseRow` and `parseAtomWithScripts` so the
    /// two paths can't drift.
    private static func attachScriptsAndPrimes(_ node: MathNode, _ tokens: inout ArraySlice<Token>) -> MathNode {
        // Primes bind before scripts: a run of ' becomes a superscript of ′.
        var primes = 0
        while tokens.first == .character("'") { tokens.removeFirst(); primes += 1 }

        var sub: MathNode?
        var sup: MathNode?
        while let mark = tokens.first, mark == .superscriptMark || mark == .subscriptMark {
            tokens.removeFirst()
            let script = parseAtom(&tokens) ?? .row([])
            if mark == .superscriptMark { sup = script } else { sub = script }
        }
        if primes > 0 {
            let primeGlyphs = MathNode.symbol(String(repeating: "\u{2032}", count: primes), .ordinary, style: .roman)
            // f'^2 → the primes lead, then the explicit exponent.
            sup = sup.map { .row([primeGlyphs, $0]) } ?? primeGlyphs
        }
        guard sub != nil || sup != nil else { return node }
        return .scripts(base: node, subscript: sub, superscript: sup)
    }

    private static func characterNode(_ ch: Character) -> MathNode {
        if ch.isNumber || ch == "." {
            return .symbol(String(ch), .ordinary, style: .roman)
        }
        // ASCII letters are italic variables; other letters (Greek α typed
        // directly, etc.) keep the class the symbol table assigns their
        // glyph so `α` matches `\alpha` and stays italic ordinary.
        if ch.isLetter {
            if ch.isASCII {
                return .symbol(String(ch), .ordinary, style: .italic)
            }
            let cls = glyphAtomClass[String(ch)] ?? .ordinary
            return .symbol(String(ch), cls, style: .italic)
        }
        switch ch {
        case "+", "−": return .symbol(String(ch), .binary, style: .roman)
        case "-": return .symbol("−", .binary, style: .roman) // proper minus
        case "*": return .symbol("∗", .binary, style: .roman)
        case "/": return .symbol("/", .ordinary, style: .roman)
        case "=": return .symbol("=", .relation, style: .roman)
        case "<": return .symbol("<", .relation, style: .roman)
        case ">": return .symbol(">", .relation, style: .roman)
        case "(", "[": return .symbol(String(ch), .opening, style: .roman)
        case ")", "]": return .symbol(String(ch), .closing, style: .roman)
        case ",", ";": return .symbol(String(ch), .punctuation, style: .roman)
        case "!", "?", "'", "|", ":": return .symbol(String(ch), .ordinary, style: .roman)
        default:
            // A directly-typed math glyph (∫ ∑ ≤ →): give it the atom class
            // its `\command` form would, so spacing and (for operators)
            // stacked limits work. `∫x` typed raw now behaves like `\int x`.
            if let cls = glyphAtomClass[String(ch)] {
                return .symbol(String(ch), cls, style: .roman)
            }
            return .symbol(String(ch), .ordinary, style: .roman)
        }
    }

    private static func commandNode(_ name: String, _ tokens: inout ArraySlice<Token>) -> MathNode {
        // Structural commands.
        switch name {
        case "frac", "tfrac", "dfrac", "cfrac":
            let numerator = parseAtom(&tokens) ?? .row([])
            let denominator = parseAtom(&tokens) ?? .row([])
            return .fraction(numerator: numerator, denominator: denominator)

        case "binom", "dbinom", "tbinom":
            let top = parseAtom(&tokens) ?? .row([])
            let bottom = parseAtom(&tokens) ?? .row([])
            return .genfrac(top: top, bottom: bottom, hasRule: false, left: "(", right: ")")

        case "sqrt":
            // Optional degree: \sqrt[3]{x}
            var degree: MathNode?
            if tokens.first == .character("[") {
                tokens.removeFirst()
                var nodes: [MathNode] = []
                while let t = tokens.first, t != .character("]") {
                    if let atom = parseAtom(&tokens) { nodes.append(atom) }
                }
                if tokens.first == .character("]") { tokens.removeFirst() }
                degree = nodes.count == 1 ? nodes[0] : .row(nodes)
            }
            let radicand = parseAtom(&tokens) ?? .row([])
            return .radical(degree: degree, radicand: radicand)

        case "left":
            let leftDelim = takeDelimiter(&tokens) ?? "("
            var body: [MathNode] = []
            var rightDelim = ")"
            while let t = tokens.first {
                if case .command("right") = t {
                    tokens.removeFirst()
                    rightDelim = takeDelimiter(&tokens) ?? ")"
                    break
                }
                if let atom = parseAtomWithScripts(&tokens) { body.append(atom) }
            }
            return .delimited(left: leftDelim, body: body.count == 1 ? body[0] : .row(body), right: rightDelim)

        case "text", "mathrm", "operatorname", "textrm":
            // The tokenizer captured the body verbatim (spaces preserved).
            if case .rawText(let s)? = tokens.first {
                tokens.removeFirst()
                return .functionName(s)
            }
            return .row([])

        case "mathbb", "mathcal", "mathscr", "mathfrak", "mathsf",
             "mathtt", "mathbf", "boldsymbol", "bm":
            let inner = parseAtom(&tokens) ?? .row([])
            return styledLetters(inner, command: name)

        case "begin":
            return parseEnvironment(&tokens)

        case "hat", "check", "tilde", "bar", "vec", "dot", "ddot", "breve",
             "mathring", "acute", "grave", "widehat", "widetilde",
             "overline", "underline":
            // The case list and MathAccent.init? must agree; rather than trust
            // that (a force-unwrap would violate the never-crash contract),
            // degrade to .unsupported if they ever drift.
            guard let accent = MathAccent(command: name) else { return .unsupported("\\" + name) }
            let base = parseAtom(&tokens) ?? .row([])
            return .accent(base: base, accent: accent)

        case "overset", "stackrel":
            // \overset{over}{base}; \stackrel is the same with a relation base.
            let over = parseAtom(&tokens) ?? .row([])
            let base = parseAtom(&tokens) ?? .row([])
            return .overUnder(base: base, over: over, under: nil, kind: .plain)

        case "underset":
            let under = parseAtom(&tokens) ?? .row([])
            let base = parseAtom(&tokens) ?? .row([])
            return .overUnder(base: base, over: nil, under: under, kind: .plain)

        case "overbrace":
            let body = parseAtom(&tokens) ?? .row([])
            var label: MathNode?
            if tokens.first == .superscriptMark {
                tokens.removeFirst()
                label = parseAtom(&tokens)
            }
            return .overUnder(base: body, over: label, under: nil, kind: .overbrace)

        case "underbrace":
            let body = parseAtom(&tokens) ?? .row([])
            var label: MathNode?
            if tokens.first == .subscriptMark {
                tokens.removeFirst()
                label = parseAtom(&tokens)
            }
            return .overUnder(base: body, over: nil, under: label, kind: .underbrace)

        case "xrightarrow", "xleftarrow":
            // \xrightarrow[under]{over} — optional [under], then {over}.
            var under: MathNode?
            if tokens.first == .character("[") {
                tokens.removeFirst()
                var nodes: [MathNode] = []
                while let t = tokens.first, t != .character("]") {
                    if let atom = parseAtom(&tokens) { nodes.append(atom) }
                }
                if tokens.first == .character("]") { tokens.removeFirst() }
                under = nodes.count == 1 ? nodes[0] : .row(nodes)
            }
            let over = parseAtom(&tokens) ?? .row([])
            return .overUnder(base: .row([]), over: over, under: under,
                              kind: name == "xrightarrow" ? .rightarrow : .leftarrow)

        case "substack":
            return parseSubstack(&tokens)

        case "boxed":
            return .decorated(base: parseAtom(&tokens) ?? .row([]), decoration: .boxed)
        case "phantom":
            return .decorated(base: parseAtom(&tokens) ?? .row([]), decoration: .phantom)
        case "hphantom":
            return .decorated(base: parseAtom(&tokens) ?? .row([]), decoration: .hphantom)
        case "vphantom":
            return .decorated(base: parseAtom(&tokens) ?? .row([]), decoration: .vphantom)

        case "color", "textcolor":
            // \color{name}{body} and \textcolor{name}{body} both take the
            // color as a brace name then the body (we don't support the
            // stateful \color{name}-applies-to-rest form).
            let color = readBraceName(&tokens)
            let body = parseAtom(&tokens) ?? .row([])
            return .styled(base: body, color: color)

        // Spacing.
        case ",": return .space(3.0 / 18.0)
        case ":": return .space(4.0 / 18.0)
        case ";": return .space(5.0 / 18.0)
        case "!": return .space(-3.0 / 18.0)   // negative thin space
        case "quad": return .space(1.0)
        case "qquad": return .space(2.0)
        case " ": return .space(6.0 / 18.0)

        // Manual delimiter sizing: we don't yet enlarge the fence, but the
        // size prefix must be transparent — parse the delimiter that
        // follows at normal size rather than degrading the whole
        // expression (\big( used to become a source card).
        case "big", "Big", "bigg", "Bigg",
             "bigl", "Bigl", "biggl", "Biggl",
             "bigr", "Bigr", "biggr", "Biggr",
             "bigm", "Bigm", "biggm", "Biggm":
            return parseAtom(&tokens) ?? .row([])

        default:
            if let (glyph, atomClass) = symbolTable[name] {
                return .symbol(glyph, atomClass, style: .roman)
            }
            if functionNames.contains(name) {
                return .functionName(name)
            }
            return .unsupported("\\" + name)
        }
    }

    /// An atom plus any attached scripts — needed inside \left…\right.
    private static func parseAtomWithScripts(_ tokens: inout ArraySlice<Token>) -> MathNode? {
        guard let node = parseAtom(&tokens) else { return nil }
        return attachScriptsAndPrimes(node, &tokens)
    }

    /// Reads a brace-delimited literal name like `{pmatrix}` or `{3}`.
    private static func readBraceName(_ tokens: inout ArraySlice<Token>) -> String {
        guard tokens.first == .groupOpen else { return "" }
        tokens.removeFirst()
        var name = ""
        while let t = tokens.first, t != .groupClose {
            tokens.removeFirst()
            if case .character(let ch) = t { name.append(ch) }
        }
        if tokens.first == .groupClose { tokens.removeFirst() }
        return name
    }

    /// Parses the body of `\begin{env} … \end{env}` into a `.matrix`. Cells
    /// are split on `&`, rows on `\\`; unknown environments still lay out as a
    /// bare centered grid so the content survives.
    private static func parseEnvironment(_ tokens: inout ArraySlice<Token>) -> MathNode {
        let env = readBraceName(&tokens)
        let base = env.hasSuffix("*") ? String(env.dropLast()) : env

        // `array` and `alignedat` carry a column-spec / count argument.
        if base == "array" || base == "alignedat" { _ = readBraceName(&tokens) }

        let (left, right, style): (String, String, MathMatrixStyle)
        switch base {
        case "pmatrix": (left, right, style) = ("(", ")", .centered)
        case "bmatrix": (left, right, style) = ("[", "]", .centered)
        case "Bmatrix": (left, right, style) = ("{", "}", .centered)
        case "vmatrix": (left, right, style) = ("|", "|", .centered)
        case "Vmatrix": (left, right, style) = ("‖", "‖", .centered)
        case "cases":   (left, right, style) = ("{", "", .cases)
        case "aligned", "align", "alignedat", "alignat", "split", "gather":
            (left, right, style) = ("", "", .aligned)
        default:        (left, right, style) = ("", "", .centered)   // matrix, array, …
        }

        var rows: [[MathNode]] = []
        var row: [MathNode] = []
        var cell: [MathNode] = []
        func endCell() {
            row.append(cell.count == 1 ? cell[0] : .row(cell))
            cell = []
        }
        func endRow() {
            endCell()
            rows.append(row)
            row = []
        }

        while let token = tokens.first {
            if case .command("end") = token {
                tokens.removeFirst()
                _ = readBraceName(&tokens)          // consume {env}
                break
            }
            if case .command("\\") = token { tokens.removeFirst(); endRow(); continue }
            if case .character("&") = token { tokens.removeFirst(); endCell(); continue }
            // Row rules: consume rather than let them degrade the whole grid
            // (\hline used to become an .unsupported leaf inside a cell,
            // flipping the entire array to a source card). \cline{a-b} also
            // carries a brace argument to drop.
            if case .command(let c) = token, c == "hline" || c == "hdashline" || c == "cline" {
                tokens.removeFirst()
                if c == "cline" { _ = readBraceName(&tokens) }
                continue
            }
            if let atom = parseAtomWithScripts(&tokens) {
                cell.append(atom)
            } else if tokens.first != nil {
                tokens.removeFirst()                // never spin on an unconsumable token
            }
        }
        // Flush a trailing partial row (no closing `\\`).
        if !cell.isEmpty || !row.isEmpty { endRow() }

        return .matrix(rows: rows, left: left, right: right, style: style)
    }

    /// `\substack{ line1 \\ line2 }` — a tight vertical stack, one cell per
    /// line, used under summation limits. Lowered to a single-column matrix
    /// with the `.substack` style so it reuses the grid layout.
    private static func parseSubstack(_ tokens: inout ArraySlice<Token>) -> MathNode {
        guard tokens.first == .groupOpen else { return .row([]) }
        tokens.removeFirst()
        var rows: [[MathNode]] = []
        var line: [MathNode] = []
        func endLine() { rows.append([line.count == 1 ? line[0] : .row(line)]); line = [] }
        while let token = tokens.first {
            if token == .groupClose { tokens.removeFirst(); break }
            if case .command("\\") = token { tokens.removeFirst(); endLine(); continue }
            if let atom = parseAtomWithScripts(&tokens) {
                line.append(atom)
            } else if tokens.first != nil {
                tokens.removeFirst()
            }
        }
        if !line.isEmpty { endLine() }
        return .matrix(rows: rows, left: "", right: "", style: .substack)
    }

    private static func takeDelimiter(_ tokens: inout ArraySlice<Token>) -> String? {
        guard let token = tokens.first else { return nil }
        tokens.removeFirst()
        switch token {
        case .character(let ch):
            return ch == "." ? "" : String(ch)
        case .command(let name):
            switch name {
            case "{": return "{"
            case "}": return "}"
            case "langle": return "⟨"
            case "rangle": return "⟩"
            case "lvert", "rvert", "vert": return "|"
            case "lVert", "rVert", "Vert": return "‖"
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Math font commands. `\mathbf` stays a system-font bold style;
    /// `\boldsymbol`/`\bm` are bold-italic; the rest map each letter/digit
    /// to its Mathematical-Alphanumeric-Symbols codepoint (𝔸 𝒜 𝔞 𝗔 𝚊 …),
    /// which CoreText resolves through STIX/Apple Symbols. The mapped glyph
    /// already encodes the styling, so it carries `.roman` to avoid a
    /// synthetic italic slant on top of it.
    private static func styledLetters(_ node: MathNode, command: String) -> MathNode {
        // `\mathbf` is the one command we render with a real bold system
        // font rather than a codepoint (matches long-standing behavior).
        if command == "mathbf" {
            switch node {
            case .symbol(let s, let cls, _):
                return .symbol(s, cls, style: .bold)
            case .row(let children):
                return .row(children.map { styledLetters($0, command: command) })
            default:
                return node
            }
        }
        guard let alphabet = MathAlphabet(command: command) else { return node }
        switch node {
        case .symbol(let s, let cls, _):
            let mapped = s.count == 1 ? (alphabet.glyph(for: s.first!) ?? s) : s
            return .symbol(mapped, cls, style: .roman)
        case .row(let children):
            return .row(children.map { styledLetters($0, command: command) })
        default:
            return node
        }
    }

}
