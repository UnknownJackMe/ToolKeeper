import Foundation

enum Sanitizer {

    // MARK: - Patterns

    private static let patterns: [NSRegularExpression] = {
        let raw = [
            "ghp_[A-Za-z0-9]+",
            "github_pat_[A-Za-z0-9]+",
            "sk-[A-Za-z0-9]+",
            "AKIA[A-Za-z0-9]+",
            "xoxb-[A-Za-z0-9-]+",
            "xoxp-[A-Za-z0-9-]+",
            "Bearer\\s[A-Za-z0-9._-]+",
            "api_key\\s*[=:]\\s*[^\\s&]+",
            "token\\s*[=:]\\s*[^\\s&]+",
            "password\\s*[=:]\\s*[^\\s&]+",
            "gh[ps]_[A-Za-z0-9_]+",
        ]
        return raw.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
    }()

    // MARK: - Public API

    static func sanitize(_ text: String) -> String {
        var result = text

        for pattern in patterns {
            let currentRange = NSRange(result.startIndex..., in: result)
            let matches = pattern.matches(in: result, range: currentRange).reversed()
            for match in matches {
                guard let range = Range(match.range, in: result) else { continue }
                result.replaceSubrange(range, with: "[REDACTED]")
            }
        }

        return result
    }
}
