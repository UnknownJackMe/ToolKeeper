import Foundation
import SwiftUI
import SwiftData

@Observable
final class ToolsViewModel {

    // MARK: - Filter State

    var searchText: String = ""
    var selectedSourceType: SourceType? = nil
    var selectedStatus: ToolStatus? = nil
    var selectedRiskLevel: RiskLevel? = nil
    var tagFilterText: String = ""
    var sortOption: SortOption = .lastUsed

    // MARK: - Sort Option

    enum SortOption: String, CaseIterable, Identifiable {
        case lastUsed = "最近使用"
        case recentlyAdded = "最近添加"
        case name = "名称"
        case riskLevel = "风险等级"

        var id: String { rawValue }
    }

    // MARK: - Filtering & Sorting

    func filteredTools(_ tools: [Tool]) -> [Tool] {
        var result = tools

        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { tool in
                tool.name.lowercased().contains(query)
                    || tool.summary.lowercased().contains(query)
                    || tool.sourceURL?.lowercased().contains(query) == true
                    || tool.localPath?.lowercased().contains(query) == true
                    || tool.notes.lowercased().contains(query)
                    || tool.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Source type filter
        if let sourceType = selectedSourceType {
            result = result.filter { $0.sourceType == sourceType }
        }

        // Status filter
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        // Risk level filter
        if let riskLevel = selectedRiskLevel {
            result = result.filter { $0.riskLevel == riskLevel }
        }

        // Tag filter (comma-separated multi-tag)
        if !tagFilterText.isEmpty {
            let filterTags = tagFilterText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            if !filterTags.isEmpty {
                result = result.filter { tool in
                    let toolTags = tool.tags.map { $0.lowercased() }
                    return filterTags.contains { filterTag in
                        toolTags.contains { $0.contains(filterTag) }
                    }
                }
            }
        }

        // Sort
        switch sortOption {
        case .lastUsed:
            result.sort { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        case .recentlyAdded:
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .riskLevel:
            result.sort { $0.riskLevel.sortOrder > $1.riskLevel.sortOrder }
        }

        return result
    }
}
