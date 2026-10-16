// Added by personal-voice (2026-10-15).
//
// Deterministic check that AI-polished text kept the parts of a dictated instruction
// whose loss would change its meaning. When the check fails the pipeline pastes the
// unpolished transcript instead of the AI output.

import Foundation

enum MeaningGuard {
    struct Violation: Equatable, CustomStringConvertible {
        enum Kind: String {
            case missingToken
            case negationDropped
        }

        let kind: Kind
        let detail: String

        var description: String { "\(kind.rawValue): \(detail)" }
    }

    struct Result: Equatable {
        let violations: [Violation]
        var isPreserved: Bool { violations.isEmpty }
    }

    /// Words whose removal flips an instruction ("do not push" -> "push").
    /// Bare "no" is excluded: it is the most common spoken self-correction cue.
    static let negations: Set<String> = [
        "not", "never", "nothing", "none", "nor", "without", "cannot", "neither", "nowhere",
        "don't", "doesn't", "didn't", "won't", "wouldn't", "can't", "couldn't", "shouldn't",
        "mustn't", "isn't", "aren't", "wasn't", "weren't", "haven't", "hasn't", "hadn't",
        "dont", "doesnt", "didnt", "wont", "cant", "shouldnt", "isnt", "arent",
    ]

    static func check(original: String, polished: String) -> Result {
        var violations: [Violation] = []

        for token in protectedTokens(in: original) where !polished.contains(token) {
            violations.append(Violation(kind: .missingToken, detail: token))
        }

        let originalNegations = negationCount(in: original)
        let polishedNegations = negationCount(in: polished)
        if polishedNegations < originalNegations {
            violations.append(
                Violation(
                    kind: .negationDropped,
                    detail: "\(originalNegations) in transcript, \(polishedNegations) in polished text"
                )
            )
        }

        return Result(violations: violations)
    }

    /// Exact strings that must survive polishing verbatim.
    static func protectedTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var seen = Set<String>()
        func add(_ raw: String) {
            let token = trimmed(raw)
            guard !token.isEmpty, seen.insert(token).inserted else { return }
            tokens.append(token)
        }

        // Inline code spans keep their content exactly.
        for match in matches(of: #"`[^`\n]+`"#, in: text) {
            add(String(match.dropFirst().dropLast()))
        }

        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            let candidate = trimmed(String(word))
            if isProtectedWord(candidate) {
                add(candidate)
            }
        }

        return tokens
    }

    static func negationCount(in text: String) -> Int {
        let normalized = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return normalized
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .filter { negations.contains(String($0)) }
            .count
    }

    // MARK: - Token classification

    private static func isProtectedWord(_ word: String) -> Bool {
        guard word.count >= 2 else { return word.first?.isNumber == true }

        // Any digit: versions, ports, counts, line numbers, 0x1F, 50%, v2, gpt-4.
        if word.contains(where: \.isNumber) { return true }
        // URLs, emails, paths, flags, env vars, operators.
        if word.contains("://") || word.contains("@") || word.contains("/") || word.contains("\\") { return true }
        if word.hasPrefix("-"), let next = word.dropFirst().first, next.isLetter || next == "-" { return true }
        if word.hasPrefix("$") || word.hasPrefix("~") || word.hasPrefix(".") { return true }
        if word.contains("_") || word.contains("::") || word.contains("=") || word.contains("()") { return true }
        // file.ext, module.member (two-letter minimum before the dot skips "e.g." and "i.e.")
        if word.range(of: #"^[A-Za-z][\w-]+\.[A-Za-z][\w.]*$"#, options: .regularExpression) != nil { return true }
        // camelCase / PascalCase identifiers (an uppercase letter after a lowercase one).
        if word.range(of: #"[a-z][A-Z]"#, options: .regularExpression) != nil { return true }
        // Acronyms and SCREAMING words of 2+ letters (API, CI, HEAD).
        if word.allSatisfy({ $0.isUppercase || $0.isNumber }) { return true }
        return false
    }

    /// Strips sentence punctuation and wrapping quotes, keeping characters that belong to code.
    private static func trimmed(_ word: String) -> String {
        var result = Substring(word)
        let leading: Set<Character> = ["\"", "'", "(", "[", "{", "\u{201C}", "\u{2018}", "`"]
        let trailing: Set<Character> = [
            ",", ";", ":", "!", "?", ".", "\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}", "`",
        ]
        while let first = result.first, leading.contains(first) { result = result.dropFirst() }
        while let last = result.last, trailing.contains(last) {
            // Keep a closing bracket that pairs with an opener inside the token, e.g. `foo()` or `a[0]`.
            if let opener = ["]": "[", ")": "(", "}": "{"][String(last)],
                result.filter({ String($0) == opener }).count >= result.filter({ $0 == last }).count
            {
                break
            }
            result = result.dropLast()
        }
        return String(result)
    }

    private static func matches(of pattern: String, in text: String) -> [Substring] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { text[$0] }
        }
    }
}
