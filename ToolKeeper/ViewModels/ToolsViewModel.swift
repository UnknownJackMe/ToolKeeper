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
    var tagFilter: String = ""
    var sortOrder: SortOrder = .recentlyUsed

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable, Identifiable {
        case recentlyUsed
        case recentlyAdded
        case name
        case riskLevel

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .recentlyUsed: return "Recently Used"
            case .recentlyAdded: return "Recently Added"
            case .name: return "Name"
            case .riskLevel: return "Risk Level"
            }
        }
    }

    // MARK: - Filtering & Sorting

    func filteredTools(_ tools: [Tool]) -> [Tool] {
        var result = tools

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { tool in
                tool.name.lowercased().contains(query)
                    || tool.summary.lowercased().contains(query)
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

        // Tag filter
        if !tagFilter.isEmpty {
            let query = tagFilter.lowercased()
            result = result.filter { tool in
                tool.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Sort
        switch sortOrder {
        case .recentlyUsed:
            result.sort { lhs, rhs in
                let lDate = lhs.lastUsedAt ?? .distantPast
                let rDate = rhs.lastUsedAt ?? .distantPast
                return lDate > rDate
            }
        case .recentlyAdded:
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .riskLevel:
            result.sort { $0.riskLevel.sortOrder < $1.riskLevel.sortOrder }
        }

        return result
    }
}
