import Foundation

/// LaTeX math lexer: source string → `Token` stream.
extension MathParser {

    enum Token: Equatable {
        case command(String)   // \frac, \alpha
        case character(Character)
        case groupOpen         // {
        case groupClose        // }
        case superscriptMark   // ^
        case subscriptMark     // _
    }

    struct Tokenizer {
        let input: [Character]
        init(_ s: String) { input = Array(s) }

        func tokenize() -> [Token] {
            var tokens: [Token] = []
            var i = 0
            while i < input.count {
                let ch = input[i]
                switch ch {
                case "\\":
                    var name = ""
                    var j = i + 1
                    while j < input.count, input[j].isLetter {
                        name.append(input[j])
                        j += 1
                    }
                    if name.isEmpty, j < input.count {
                        // Escaped single char: \{ \} \, \$ etc.
                        name = String(input[j])
                        j += 1
                    }
                    tokens.append(.command(name))
                    i = j
                case "{": tokens.append(.groupOpen); i += 1
                case "}": tokens.append(.groupClose); i += 1
                case "^": tokens.append(.superscriptMark); i += 1
                case "_": tokens.append(.subscriptMark); i += 1
                case " ", "\n", "\t": i += 1 // math mode ignores whitespace
                default:
                    tokens.append(.character(ch)); i += 1
                }
            }
            return tokens
        }
    }
}
