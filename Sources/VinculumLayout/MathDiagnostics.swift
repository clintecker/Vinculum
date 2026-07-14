import Foundation

/// A diagnosable parse problem, locatable in the source (Phase 8c) — the
/// squiggle-underline substrate for live-editor hosts. iosMath surfaces
/// message-only NSErrors; the range is Vinculum's differentiator.
public struct MathParseIssue: Sendable, Equatable {
    /// The offending source snippet, e.g. `"\badcmd"`.
    public let source: String
    /// Human-readable description.
    public let message: String
    /// Where `source` sits in the diagnosed string — nil when the snippet
    /// can't be located (e.g. it was produced by macro expansion). A nil
    /// range is honest; a wrong range never is.
    public let range: Range<String.Index>?
}

/// Support classification: native render vs. named source-card fallback.
extension MathParser {

    /// Diagnoses `latex`, returning one issue per unsupported token in
    /// source order, each with its location. Pass `parsing:` when the text
    /// actually parsed differs from what the user typed (macro expansion);
    /// ranges then refer to `latex` and fall back to nil when unlocatable.
    public static func diagnostics(for latex: String, parsing: String? = nil) -> [MathParseIssue] {
        let node = parse(parsing ?? latex)
        var snippets: [String] = []
        walkUnsupported(node) { snippets.append($0) }

        var issues: [MathParseIssue] = []
        var searchFrom = latex.startIndex
        for raw in snippets {
            let isCommand = raw.hasPrefix("\\") && raw.dropFirst().allSatisfy(\.isLetter)
                && raw.count > 1
            let message = isCommand
                ? "unsupported command \(raw)"
                : "unsupported input “\(raw)”"
            // Locate this occurrence: search forward from the previous hit so
            // duplicates map to successive positions; fall back to a
            // whole-string search, then to nil.
            let range = latex.range(of: raw, range: searchFrom..<latex.endIndex)
                ?? latex.range(of: raw)
            if let range { searchFrom = range.upperBound }
            issues.append(MathParseIssue(source: raw, message: message, range: range))
        }
        return issues
    }

    /// Ordered, non-deduped walk of `.unsupported` leaves.
    private static func walkUnsupported(_ node: MathNode, _ emit: (String) -> Void) {
        switch node {
        case .unsupported(let raw):
            emit(raw)
        case .symbol, .space, .functionName, .ruleBox, .bigDelimiter:
            break
        case .row(let children):
            children.forEach { walkUnsupported($0, emit) }
        case .fraction(let n, let d), .cfrac(let n, let d, _):
            walkUnsupported(n, emit); walkUnsupported(d, emit)
        case .radical(let degree, let radicand):
            degree.map { walkUnsupported($0, emit) }; walkUnsupported(radicand, emit)
        case .scripts(let base, let sub, let sup):
            walkUnsupported(base, emit)
            sub.map { walkUnsupported($0, emit) }
            sup.map { walkUnsupported($0, emit) }
        case .delimited(_, let body, _):
            walkUnsupported(body, emit)
        case .fenced(_, let segments):
            segments.forEach { walkUnsupported($0, emit) }
        case .limitsOperator(let base), .classified(let base, _), .raised(let base, _),
             .colorbox(let base, _, _), .accent(let base, _), .decorated(let base, _),
             .styled(let base, _), .mathStyle(let base, _):
            walkUnsupported(base, emit)
        case .matrix(let rows, _, _, _):
            rows.forEach { $0.forEach { walkUnsupported($0, emit) } }
        case .genfrac(let top, let bottom, _, _, _):
            walkUnsupported(top, emit); walkUnsupported(bottom, emit)
        case .overUnder(let base, let over, let under, _):
            walkUnsupported(base, emit)
            over.map { walkUnsupported($0, emit) }
            under.map { walkUnsupported($0, emit) }
        }
    }

    public static func isFullySupported(_ node: MathNode) -> Bool {
        switch node {
        case .unsupported:
            return false
        case .symbol, .space, .functionName:
            return true
        case .row(let children):
            return children.allSatisfy(isFullySupported)
        case .fraction(let n, let d), .cfrac(let n, let d, _):
            return isFullySupported(n) && isFullySupported(d)
        case .radical(let degree, let radicand):
            return (degree.map(isFullySupported) ?? true) && isFullySupported(radicand)
        case .scripts(let base, let sub, let sup):
            return isFullySupported(base)
                && (sub.map(isFullySupported) ?? true)
                && (sup.map(isFullySupported) ?? true)
        case .delimited(_, let body, _):
            return isFullySupported(body)
        case .fenced(_, let segments):
            return segments.allSatisfy(isFullySupported)
        case .limitsOperator(let base):
            return isFullySupported(base)
        case .classified(let base, _), .raised(let base, _), .colorbox(let base, _, _):
            return isFullySupported(base)
        case .ruleBox:
            return true
        case .matrix(let rows, _, _, _):
            return rows.allSatisfy { $0.allSatisfy(isFullySupported) }
        case .accent(let base, _):
            return isFullySupported(base)
        case .genfrac(let top, let bottom, _, _, _):
            return isFullySupported(top) && isFullySupported(bottom)
        case .overUnder(let base, let over, let under, _):
            return isFullySupported(base)
                && (over.map(isFullySupported) ?? true)
                && (under.map(isFullySupported) ?? true)
        case .decorated(let base, _):
            return isFullySupported(base)
        case .styled(let base, _):
            return isFullySupported(base)
        case .mathStyle(let base, _):
            return isFullySupported(base)
        case .bigDelimiter:
            return true
        }
    }

    /// The distinct commands that degraded this expression to source
    /// fallback, in first-seen order (deduped, capped). `isFullySupported`
    /// answers "did it degrade"; this answers "on WHAT" so the fallback
    /// card can name the culprit instead of a generic apology.
    public static func unsupportedCommands(in node: MathNode, limit: Int = 4) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        func walk(_ node: MathNode) {
            switch node {
            case .unsupported(let raw):
                // The payload is the raw token ("\\foo" or a stray char).
                // Only surface real letter-commands (`\word`) — structural
                // noise like a stray `\\` row separator isn't a nameable
                // culprit and would just confuse the caption.
                let name = raw.hasPrefix("\\") ? raw : "\\" + raw
                let body = name.dropFirst()
                guard !body.isEmpty, body.allSatisfy(\.isLetter) else { break }
                if seen.insert(name).inserted { ordered.append(name) }
            case .symbol, .space, .functionName:
                break
            case .row(let children):
                children.forEach(walk)
            case .fraction(let n, let d), .cfrac(let n, let d, _):
                walk(n); walk(d)
            case .radical(let degree, let radicand):
                degree.map(walk); walk(radicand)
            case .scripts(let base, let sub, let sup):
                walk(base); sub.map(walk); sup.map(walk)
            case .delimited(_, let body, _):
                walk(body)
            case .fenced(_, let segments):
                segments.forEach(walk)
            case .limitsOperator(let base):
                walk(base)
            case .classified(let base, _), .raised(let base, _), .colorbox(let base, _, _):
                walk(base)
            case .ruleBox:
                break
            case .matrix(let rows, _, _, _):
                rows.forEach { $0.forEach(walk) }
            case .accent(let base, _):
                walk(base)
            case .genfrac(let top, let bottom, _, _, _):
                walk(top); walk(bottom)
            case .overUnder(let base, let over, let under, _):
                walk(base); over.map(walk); under.map(walk)
            case .decorated(let base, _):
                walk(base)
            case .styled(let base, _):
                walk(base)
            case .mathStyle(let base, _):
                walk(base)
            case .bigDelimiter:
                break
            }
        }
        walk(node)
        return Array(ordered.prefix(limit))
    }
}
