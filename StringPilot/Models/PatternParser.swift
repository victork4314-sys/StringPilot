import Foundation

enum PatternParseError: LocalizedError, Equatable {
    case empty
    case invalidToken(String)
    case stringOutOfRange(Int, maximum: Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter at least one string number or rest."
        case .invalidToken(let token):
            return "“\(token)” is not a string number or rest."
        case .stringOutOfRange(let value, let maximum):
            return "String \(value) is outside this instrument’s 1–\(maximum) range."
        }
    }
}

struct PatternParser {
    func parse(_ text: String, maximumString: Int) throws -> [PatternStep] {
        let normalized = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .replacingOccurrences(of: "|", with: " ")

        let tokens = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { throw PatternParseError.empty }

        return try tokens.map { rawToken in
            var token = rawToken.lowercased()
            let accent = token.hasSuffix("!")
            if accent { token.removeLast() }

            if token == "-" || token == "r" || token == "rest" || token == "0" {
                return PatternStep(stringNumber: nil, accent: accent)
            }

            guard let value = Int(token) else {
                throw PatternParseError.invalidToken(rawToken)
            }
            guard (1...maximumString).contains(value) else {
                throw PatternParseError.stringOutOfRange(value, maximum: maximumString)
            }
            return PatternStep(stringNumber: value, accent: accent)
        }
    }

    func render(_ steps: [PatternStep]) -> String {
        steps.map { step in
            let base = step.stringNumber.map(String.init) ?? "-"
            return step.accent ? base + "!" : base
        }.joined(separator: " ")
    }
}
