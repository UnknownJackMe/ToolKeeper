import Foundation

// MARK: - Data Structures

struct AIToolItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let tags: [String]
    let category: String
    let version: String?
    let sourcePath: String
    let sourceType: SourceType
    let itemType: AIToolItemType
    let isSymlink: Bool
    let isEnabled: Bool
    let contentPreview: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AIToolItem, rhs: AIToolItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum AIToolItemType: String, CaseIterable, Identifiable {
    case skill
    case agent
    case command
    case automation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .skill:      return "技能"
        case .agent:      return "代理"
        case .command:    return "命令"
        case .automation: return "自动化"
        }
    }

    var icon: String {
        switch self {
        case .skill:      return "sparkles"
        case .agent:      return "person.circle"
        case .command:    return "terminal"
        case .automation: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Scanner

enum ClaudeCodeScanner {

    static func scanAll() -> [AIToolItem] {
        var items: [AIToolItem] = []
        items.append(contentsOf: scanClaudeCodeSkills())
        items.append(contentsOf: scanClaudeCodeAgents())
        items.append(contentsOf: scanClaudeCodeCommands())
        items.append(contentsOf: scanCodexSkills())
        items.append(contentsOf: scanCodexAutomations())
        return items
    }

    // MARK: - Claude Code Skills

    private static func scanClaudeCodeSkills() -> [AIToolItem] {
        let skillsDir = NSHomeDirectory() + "/.claude/skills"
        return scanSkillDirectories(in: skillsDir, sourceType: .claudeCode)
    }

    // MARK: - Claude Code Agents

    private static func scanClaudeCodeAgents() -> [AIToolItem] {
        let agentsDir = NSHomeDirectory() + "/.claude/agents"
        return scanMarkdownFiles(in: agentsDir, sourceType: .claudeCode, itemType: .agent)
    }

    // MARK: - Claude Code Commands

    private static func scanClaudeCodeCommands() -> [AIToolItem] {
        let commandsDir = NSHomeDirectory() + "/.claude/commands"
        return scanMarkdownFiles(in: commandsDir, sourceType: .claudeCode, itemType: .command)
    }

    // MARK: - Codex Skills

    private static func scanCodexSkills() -> [AIToolItem] {
        let skillsDir = NSHomeDirectory() + "/.codex/skills"
        return scanSkillDirectories(in: skillsDir, sourceType: .codex)
    }

    // MARK: - Codex Automations

    private static func scanCodexAutomations() -> [AIToolItem] {
        let automationsDir = NSHomeDirectory() + "/.codex/automations"
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: automationsDir) else { return [] }

        var items: [AIToolItem] = []
        for entry in entries {
            let fullPath = (automationsDir as NSString).appendingPathComponent(entry)
            let tomlPath = (fullPath as NSString).appendingPathComponent("automation.toml")

            guard fm.fileExists(atPath: tomlPath) else { continue }

            let (isSymlink, isEnabled) = inspectPath(fullPath)
            let tomlContent = (try? String(contentsOfFile: tomlPath, encoding: .utf8)) ?? ""
            let metadata = parseToml(tomlContent)

            let item = AIToolItem(
                name: metadata["name"] ?? entry,
                description: metadata["prompt"] ?? "",
                tags: [],
                category: metadata["kind"] ?? "cron",
                version: nil,
                sourcePath: fullPath,
                sourceType: .codex,
                itemType: .automation,
                isSymlink: isSymlink,
                isEnabled: isEnabled,
                contentPreview: String(tomlContent.prefix(500))
            )
            items.append(item)
        }
        return items
    }

    // MARK: - Shared Helpers

    private static func scanSkillDirectories(in parentDir: String, sourceType: SourceType) -> [AIToolItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: parentDir) else { return [] }

        var items: [AIToolItem] = []
        for entry in entries {
            // Skip hidden directories (like .system)
            if entry.hasPrefix(".") { continue }

            let fullPath = (parentDir as NSString).appendingPathComponent(entry)
            let skillMdPath = (fullPath as NSString).appendingPathComponent("SKILL.md")

            guard fm.fileExists(atPath: skillMdPath) else { continue }

            let (isSymlink, isEnabled) = inspectPath(fullPath)
            let skillContent = (try? String(contentsOfFile: skillMdPath, encoding: .utf8)) ?? ""
            let metadata = parseFrontmatter(skillContent)

            let metadataJsonPath = (fullPath as NSString).appendingPathComponent("metadata.json")
            var jsonMetadata: [String: String] = [:]
            if let jsonData = try? Data(contentsOf: URL(fileURLWithPath: metadataJsonPath)),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                jsonMetadata["display_name"] = json["display_name"] as? String
                jsonMetadata["quality_tier"] = (json["quality"] as? [String: Any])?["tier"] as? String
            }

            let name = metadata["name"] ?? jsonMetadata["display_name"] ?? entry
            let description = metadata["description"] ?? ""
            let tags = parseTags(metadata["tags"] ?? "")
            let category = metadata["category"] ?? ""
            let version = metadata["version"]

            let item = AIToolItem(
                name: name,
                description: description,
                tags: tags,
                category: category,
                version: version,
                sourcePath: fullPath,
                sourceType: sourceType,
                itemType: .skill,
                isSymlink: isSymlink,
                isEnabled: isEnabled,
                contentPreview: String(skillContent.prefix(500))
            )
            items.append(item)
        }
        return items
    }

    private static func scanMarkdownFiles(in parentDir: String, sourceType: SourceType, itemType: AIToolItemType) -> [AIToolItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: parentDir) else { return [] }

        var items: [AIToolItem] = []
        for entry in entries {
            guard entry.hasSuffix(".md") else { continue }

            let fullPath = (parentDir as NSString).appendingPathComponent(entry)
            let (isSymlink, isEnabled) = inspectPath(fullPath)
            let content = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
            let name = (entry as NSString).deletingPathExtension

            // Extract title from first heading
            let title: String
            if let firstLine = content.components(separatedBy: .newlines).first(where: { $0.hasPrefix("# ") }) {
                title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else {
                title = name
            }

            let item = AIToolItem(
                name: title,
                description: String(content.prefix(200)),
                tags: [],
                category: "",
                version: nil,
                sourcePath: fullPath,
                sourceType: sourceType,
                itemType: itemType,
                isSymlink: isSymlink,
                isEnabled: isEnabled,
                contentPreview: String(content.prefix(500))
            )
            items.append(item)
        }
        return items
    }

    private static func inspectPath(_ path: String) -> (isSymlink: Bool, isEnabled: Bool) {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: path)
        let isSymlink = attrs?[.type] as? FileAttributeType == .typeSymbolicLink
        let isEnabled = !path.hasSuffix(".disabled")
        return (isSymlink, isEnabled)
    }

    // MARK: - YAML Frontmatter Parser

    private static func parseFrontmatter(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return result }

        var inFrontmatter = false
        var frontmatterLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if inFrontmatter { break }
                inFrontmatter = true
                continue
            }
            if inFrontmatter {
                frontmatterLines.append(line)
            }
        }

        for line in frontmatterLines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            result[key] = value
        }

        return result
    }

    private static func parseTags(_ tagsString: String) -> [String] {
        // Handle YAML array format: ["tag1", "tag2"] or [tag1, tag2]
        let cleaned = tagsString
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")

        return cleaned
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Simple TOML Parser

    private static func parseToml(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}
