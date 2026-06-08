import Foundation

enum RiskClassifier {

    // MARK: - Patterns

    private static let highPatterns: [NSRegularExpression] = {
        let raw = [
            "rm\\s+-rf",
            "sudo\\s",
            "curl.*\\|.*sh",
            "wget.*\\|.*sh",
            "dd\\s",
            "mkfs",
            "diskutil\\s+erase",
            "launchctl\\s+unload",
            "launchctl\\s+bootout",
        ]
        return raw.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
    }()

    private static let mediumPatterns: [NSRegularExpression] = {
        let raw = [
            "chmod\\s+-R",
            "chown\\s+-R",
            "brew\\s+install",
            "npm\\s+install\\s+-g",
            "pip\\s+install",
            "eval\\s",
        ]
        return raw.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
    }()

    // MARK: - Public API

    static func classify(command: String) -> RiskLevel {
        let range = NSRange(command.startIndex..., in: command)

        for pattern in highPatterns {
            if pattern.firstMatch(in: command, range: range) != nil {
                return .high
            }
        }

        for pattern in mediumPatterns {
            if pattern.firstMatch(in: command, range: range) != nil {
                return .medium
            }
        }

        return .low
    }
}
