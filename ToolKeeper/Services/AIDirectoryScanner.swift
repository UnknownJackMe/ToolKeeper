import Foundation

struct DirectoryContext {
    let path: String
    let tree: String
    let fileContents: String
}

enum AIDirectoryScanner {

    private static let skipDirs: Set<String> = [
        "node_modules", ".git", "Library", "Applications",
        "venv", ".venv", "target", "dist", "build",
        ".cache", ".DS_Store", ".Trash", ".build",
        "DerivedData", ".swiftpm",
    ]

    private static let interestingFiles: [String] = [
        "README.md", "README", "package.json", "Makefile",
        "pyproject.toml", "Cargo.toml", "SKILL.md",
        "automation.toml", ".git/config",
    ]

    static func scanDirectory(at path: String) -> DirectoryContext {
        let tree = buildTree(at: path, depth: 0, maxDepth: 3)
        let contents = collectFileContents(at: path, depth: 0, maxDepth: 2)
        return DirectoryContext(path: path, tree: tree, fileContents: contents)
    }

    // MARK: - Tree Builder

    private static func buildTree(at path: String, depth: Int, maxDepth: Int) -> String {
        guard depth <= maxDepth else { return "" }

        let fm = FileManager.default
        let indent = String(repeating: "  ", count: depth)
        var lines: [String] = []

        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return "" }

        let sorted = entries
            .filter { !$0.hasPrefix(".") || $0 == ".git" }
            .sorted()

        for entry in sorted {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)

            if isDir.boolValue {
                if skipDirs.contains(entry) {
                    lines.append("\(indent)\u{1F4C1} \(entry)/ [跳过]")
                } else {
                    lines.append("\(indent)\u{1F4C1} \(entry)/")
                    lines.append(buildTree(at: fullPath, depth: depth + 1, maxDepth: maxDepth))
                }
            } else {
                let size = (try? fm.attributesOfItem(atPath: fullPath))?[.size] as? Int ?? 0
                let sizeStr = formatSize(size)
                lines.append("\(indent)\u{1F4C4} \(entry) (\(sizeStr))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - File Content Collector

    private static func collectFileContents(at path: String, depth: Int, maxDepth: Int) -> String {
        guard depth <= maxDepth else { return "" }

        let fm = FileManager.default
        var parts: [String] = []

        for filename in interestingFiles {
            let filePath = (path as NSString).appendingPathComponent(filename)
            guard fm.fileExists(atPath: filePath),
                  let data = fm.contents(atPath: filePath),
                  let content = String(data: data, encoding: .utf8) else { continue }

            let relativePath = depth == 0 ? filename : {
                let parentName = (path as NSString).lastPathComponent
                return "\(parentName)/\(filename)"
            }()

            let truncated = String(content.prefix(2000))
            parts.append("=== \(relativePath) ===\n\(truncated)\n")
        }

        if depth < maxDepth {
            guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return parts.joined(separator: "\n") }

            for entry in entries.sorted() {
                guard !entry.hasPrefix(".") else { continue }
                let fullPath = (path as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir),
                      isDir.boolValue,
                      !skipDirs.contains(entry) else { continue }

                let subContents = collectFileContents(at: fullPath, depth: depth + 1, maxDepth: maxDepth)
                if !subContents.isEmpty {
                    parts.append(subContents)
                }
            }
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024)KB" }
        return "\(bytes / 1024 / 1024)MB"
    }

    // MARK: - Prompt Builder

    static func buildPrompt(for context: DirectoryContext) -> String {
        """
        你是工具分析助手。请递归分析以下目录，识别其中所有独立的工具/项目。

        目录路径: \(context.path)

        目录结构:
        \(context.tree)

        各子目录的关键文件内容:
        \(context.fileContents)

        请返回一个 JSON 对象，格式严格如下（不要包含任何其他文字、解释或 markdown 标记）:
        {
          "tools": [
            {
              "name": "工具名称",
              "summary": "一句话描述该工具的用途",
              "sourceType": "github",
              "sourceURL": "https://github.com/owner/repo（如有）",
              "localPath": "/absolute/path/to/tool",
              "tags": ["标签1", "标签2"],
              "commands": [
                {
                  "name": "命令显示名",
                  "commandText": "实际执行的命令",
                  "description": "该命令的作用"
                }
              ],
              "importType": "tool"
            }
          ]
        }

        sourceType 可选值: github, local, script, homebrew, npm, pip, binary, claudeCode, codex, unknown
        importType 说明:
        - "tool": 普通工具（脚本、项目、CLI 工具等）
        - "aiTool": AI 相关工具（Claude Code 的 skill/agent/command，Codex 的 skill/automation 等）

        判断 importType 的依据:
        - 如果目录包含 SKILL.md、在 ~/.claude/skills 或 ~/.codex/skills 下 → aiTool
        - 如果目录包含 .claude/commands/*.md 或 .claude/agents/*.md → aiTool
        - 如果目录包含 automation.toml → aiTool
        - 其他情况 → tool

        如果目录下只有一个项目，也请返回一个 tools 数组（包含一个元素）。
        如果没有找到任何可识别的工具/项目，返回 {"tools": []}。
        """
    }
}
