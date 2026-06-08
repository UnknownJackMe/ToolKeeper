import Foundation
import SwiftUI
import SwiftData

struct AIToolSuggestion: Codable, Identifiable {
    let id = UUID()
    var name: String
    var summary: String
    var sourceType: String
    var sourceURL: String?
    var localPath: String?
    var tags: [String]
    var commands: [SuggestedCommand]
    var importType: String

    enum CodingKeys: String, CodingKey {
        case name, summary, sourceType, sourceURL, localPath, tags, commands, importType
    }
}

struct SuggestedCommand: Codable, Identifiable {
    let id = UUID()
    var name: String
    var commandText: String
    var description: String?

    enum CodingKeys: String, CodingKey {
        case name, commandText, description
    }
}

@Observable @MainActor
final class AIImportViewModel {

    var directoryPath: String = ""
    var isAnalyzing: Bool = false
    var errorMessage: String?
    var suggestions: [AIToolSuggestion] = []
    var selectedIndices: Set<Int> = []
    var importedCount: Int = 0

    var hasSelection: Bool { !selectedIndices.isEmpty }

    var selectedSuggestions: [AIToolSuggestion] {
        selectedIndices.sorted().compactMap { suggestions[safe: $0] }
    }

    // MARK: - Directory Picker

    func pickDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择要分析的目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if !directoryPath.isEmpty {
            let expanded = (directoryPath as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                panel.directoryURL = URL(fileURLWithPath: expanded)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path
            suggestions = []
            selectedIndices = []
            errorMessage = nil
        }
    }

    // MARK: - Analysis

    func analyzeDirectory() {
        guard !directoryPath.isEmpty else {
            errorMessage = "请先选择目录"
            return
        }

        guard FileManager.default.fileExists(atPath: directoryPath) else {
            errorMessage = "目录不存在: \(directoryPath)"
            return
        }

        let settings = AppSettings.load()
        guard !settings.anthropicAPIKey.isEmpty else {
            errorMessage = "请先在设置中填写 API Key"
            return
        }

        isAnalyzing = true
        errorMessage = nil
        suggestions = []
        selectedIndices = []
        importedCount = 0

        let path = directoryPath
        let client = AnthropicAPIClient(
            baseURL: settings.anthropicBaseURL,
            apiKey: settings.anthropicAPIKey,
            model: settings.anthropicModel,
            useFullURL: settings.anthropicUseFullURL
        )

        Task.detached { @MainActor [weak self] in
            guard let self else { return }

            do {
                let context = AIDirectoryScanner.scanDirectory(at: path)
                let prompt = AIDirectoryScanner.buildPrompt(for: context)
                let response = try await client.sendStructured(prompt: prompt, maxTokens: 8192)

                let parsed = try self.parseSuggestions(from: response)
                self.suggestions = parsed
                self.selectedIndices = Set(parsed.indices)
                self.isAnalyzing = false
            } catch {
                self.errorMessage = "分析失败: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }

    // MARK: - Edit

    func updateSuggestion(at index: Int, with updated: AIToolSuggestion) {
        guard suggestions.indices.contains(index) else { return }
        suggestions[index] = updated
    }

    // MARK: - Import

    func importSelected(modelContext: ModelContext) {
        guard !selectedIndices.isEmpty else { return }

        let existingDescriptor = FetchDescriptor<Tool>()
        let existingTools = (try? modelContext.fetch(existingDescriptor)) ?? []
        let existingNames = Set(existingTools.map { $0.name })

        var added = 0
        for index in selectedIndices.sorted() {
            let suggestion = suggestions[index]

            guard !existingNames.contains(suggestion.name) else { continue }

            let sourceType = SourceType(rawValue: suggestion.sourceType) ?? .unknown

            let tool = Tool(
                name: suggestion.name,
                summary: suggestion.summary,
                sourceType: sourceType,
                sourceURL: suggestion.sourceURL,
                localPath: suggestion.localPath,
                tags: suggestion.tags,
                status: .active,
                riskLevel: .low
            )

            for cmd in suggestion.commands {
                let toolCmd = ToolCommand(
                    toolID: tool.id,
                    name: cmd.name,
                    commandText: cmd.commandText,
                    commandDescription: cmd.description ?? ""
                )
                tool.commands = (tool.commands ?? []) + [toolCmd]
            }

            modelContext.insert(tool)
            added += 1
        }

        if added > 0 {
            try? modelContext.save()
        }

        importedCount = added
    }

    // MARK: - Selection Helpers

    func selectAll() {
        selectedIndices = Set(suggestions.indices)
    }

    func deselectAll() {
        selectedIndices = []
    }

    func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    func reset() {
        directoryPath = ""
        suggestions = []
        selectedIndices = []
        errorMessage = nil
        importedCount = 0
    }

    // MARK: - JSON Parsing

    private func parseSuggestions(from text: String) throws -> [AIToolSuggestion] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code block if present
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: .newlines)
            let filtered = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            cleaned = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw AnthropicAPIError.decodingError("无法将响应转换为数据")
        }

        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(ToolsResponse.self, from: data)
        return wrapper.tools
    }
}

// MARK: - Response Wrapper

private struct ToolsResponse: Codable {
    let tools: [AIToolSuggestion]
}

// MARK: - Safe Array Indexing

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
