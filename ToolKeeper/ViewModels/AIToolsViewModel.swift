import Foundation
import SwiftUI
import SwiftData

@Observable
final class AIToolsViewModel {

    var items: [AIToolItem] = []
    var searchText: String = ""
    var selectedSourceType: SourceType? = nil
    var selectedItemType: AIToolItemType? = nil
    var selectedItem: AIToolItem? = nil
    var isLoading: Bool = false

    func scan() {
        isLoading = true
        items = ClaudeCodeScanner.scanAll()
        isLoading = false
    }

    var filteredItems: [AIToolItem] {
        var result = items

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                    || $0.description.lowercased().contains(query)
                    || $0.tags.contains { $0.lowercased().contains(query) }
            }
        }

        if let sourceType = selectedSourceType {
            result = result.filter { $0.sourceType == sourceType }
        }

        if let itemType = selectedItemType {
            result = result.filter { $0.itemType == itemType }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func toggleEnabled(_ item: AIToolItem) {
        let fm = FileManager.default
        let path = item.sourcePath

        if item.isEnabled {
            // Disable: rename to add .disabled suffix
            let disabledPath = path + ".disabled"
            try? fm.moveItem(atPath: path, toPath: disabledPath)
        } else {
            // Enable: remove .disabled suffix
            guard path.hasSuffix(".disabled") else { return }
            let enabledPath = String(path.dropLast(".disabled".count))
            try? fm.moveItem(atPath: path, toPath: enabledPath)
        }

        // Re-scan to reflect changes
        scan()
    }

    func importAsTool(_ item: AIToolItem, modelContext: ModelContext) {
        let sourceType: SourceType = item.sourceType
        let tool = Tool(
            name: item.name,
            summary: item.description,
            sourceType: sourceType,
            localPath: item.sourcePath,
            tags: item.tags,
            status: .active,
            riskLevel: .low
        )
        modelContext.insert(tool)
        try? modelContext.save()
    }

    func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
