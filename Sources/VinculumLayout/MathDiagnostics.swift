import Foundation

/// Support classification: native render vs. named source-card fallback.
extension MathParser {

    public static func isFullySupported(_ node: MathNode) -> Bool {
        switch node {
        case .unsupported:
            return false
        case .symbol, .space, .functionName:
            return true
        case .row(let children):
            return children.allSatisfy(isFullySupported)
        case .fraction(let n, let d):
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
        case .classified(let base, _):
            return isFullySupported(base)
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
            case .fraction(let n, let d):
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
            case .classified(let base, _):
                walk(base)
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
