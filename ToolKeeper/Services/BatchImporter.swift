import Foundation
import SwiftData

enum BatchImporter {

    private static let importFlagPath = AppPaths.appSupport + "batch_imported.flag"

    struct ImportTool: Codable {
        let name: String
        let summary: String
        let sourceType: String
        let sourceURL: String?
        let localPath: String?
        let repoOwner: String?
        let repoName: String?
        let tags: [String]
        let status: String
        let commands: [ImportCommand]?
    }

    struct ImportCommand: Codable {
        let name: String
        let commandText: String
        let description: String?
        let requiresConfirmation: Bool?
    }

    /// Import tools from import_tools.json if not already done.
    static func importIfNeeded(modelContext: ModelContext) {
        importIfNeeded(modelContext: modelContext, jsonPath: nil, flagPath: nil)
    }

    /// Import tools with overridable paths (for testing).
    static func importIfNeeded(modelContext: ModelContext, jsonPath: String?, flagPath: String?) {
        let flag = flagPath ?? importFlagPath

        // Check if already imported
        if FileManager.default.fileExists(atPath: flag) {
            return
        }

        let resolvedPath = jsonPath ?? findImportFile()
        guard let path = resolvedPath, let data = FileManager.default.contents(atPath: path) else {
            // No JSON file, mark as done anyway
            FileManager.default.createFile(atPath: importFlagPath, contents: nil)
            return
        }

        guard let tools = try? JSONDecoder().decode([ImportTool].self, from: data) else {
            print("[BatchImporter] Failed to decode import_tools.json")
            return
        }

        // Get existing tool names to avoid duplicates
        let descriptor = FetchDescriptor<Tool>()
        let existingTools = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existingTools.map { $0.name })

        var added = 0
        for importTool in tools {
            guard !existingNames.contains(importTool.name) else {
                continue
            }

            let sourceType = SourceType(rawValue: importTool.sourceType) ?? .unknown
            let status = ToolStatus(rawValue: importTool.status) ?? .active

            let tool = Tool(
                name: importTool.name,
                summary: importTool.summary,
                sourceType: sourceType,
                sourceURL: importTool.sourceURL,
                localPath: importTool.localPath,
                repoOwner: importTool.repoOwner,
                repoName: importTool.repoName,
                tags: importTool.tags,
                status: status
            )

            for importCmd in (importTool.commands ?? []) {
                let cmd = ToolCommand(
                    toolID: tool.id,
                    name: importCmd.name,
                    commandText: importCmd.commandText,
                    commandDescription: importCmd.description ?? "",
                    requiresConfirmation: importCmd.requiresConfirmation ?? false
                )
                tool.commands = (tool.commands ?? []) + [cmd]
            }

            modelContext.insert(tool)
            added += 1
        }

        if added > 0 {
            try? modelContext.save()
            print("[BatchImporter] Imported \(added) tools")
        }

        // Mark as done
        FileManager.default.createFile(atPath: flag, contents: nil)
    }

    private static func findImportFile() -> String? {
        // 1. User data directory (primary)
        let userPath = NSHomeDirectory() + "/ToolKeeper/import_tools.json"
        if FileManager.default.fileExists(atPath: userPath) {
            return userPath
        }
        // 2. App bundle resources (fallback for first-run bundled data)
        if let bundlePath = Bundle.main.path(forResource: "import_tools", ofType: "json") {
            return bundlePath
        }
        return nil
    }
}
