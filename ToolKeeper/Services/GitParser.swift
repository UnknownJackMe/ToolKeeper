import Foundation

enum GitParser {

    /// Extracts the origin URL from git config file content.
    static func parseOriginURL(from configContent: String) -> String? {
        let lines = configContent.components(separatedBy: .newlines)
        var inOriginSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[remote ") && trimmed.contains("\"origin\"") {
                inOriginSection = true
                continue
            }

            if trimmed.hasPrefix("[") && inOriginSection {
                break
            }

            if inOriginSection, trimmed.hasPrefix("url") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }

    /// Parses a GitHub URL and returns the owner/repo pair.
    static func parseGitHubOwnerRepo(from url: String) -> (owner: String, repo: String)? {
        guard url.contains("github.com") else { return nil }

        let cleaned = url
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespaces)

        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        let owner = String(parts[0])
        let repo = String(parts[1])

        guard !owner.isEmpty, !repo.isEmpty else { return nil }
        return (owner: owner, repo: repo)
    }
}
