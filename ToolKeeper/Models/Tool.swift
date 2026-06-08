import Foundation
import SwiftData

// MARK: - Enums

enum SourceType: String, CaseIterable, Identifiable, Codable {
    case github
    case local
    case homebrew
    case npm
    case pip
    case binary
    case script
    case website
    case unknown
    case claudeCode
    case codex

    var id: String { rawValue }
}

enum ToolStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case archived
    case broken
    case unknown

    var id: String { rawValue }
}

enum RiskLevel: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

// MARK: - Tool Model

@Model
final class Tool {
    var id: UUID
    var name: String
    var summary: String
    var sourceTypeRaw: String
    var sourceURL: String?
    var localPath: String?
    var repoOwner: String?
    var repoName: String?
    var defaultWorkingDirectory: String?
    var tagsData: Data
    var statusRaw: String
    var riskLevelRaw: String
    var installCommand: String?
    var updateCommand: String?
    var uninstallCommand: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var commands: [ToolCommand]?

    @Relationship(deleteRule: .cascade)
    var runHistories: [RunHistory]?

    // MARK: - Computed Properties

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .unknown }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var status: ToolStatus {
        get { ToolStatus(rawValue: statusRaw) ?? .unknown }
        set { statusRaw = newValue.rawValue }
    }

    var riskLevel: RiskLevel {
        get { RiskLevel(rawValue: riskLevelRaw) ?? .low }
        set { riskLevelRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            guard !tagsData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: tagsData)
            } catch {
                return []
            }
        }
        set {
            do {
                tagsData = try JSONEncoder().encode(newValue)
            } catch {
                tagsData = Data()
            }
        }
    }

    // MARK: - Initializer

    init(
        name: String,
        summary: String = "",
        sourceType: SourceType = .unknown,
        sourceURL: String? = nil,
        localPath: String? = nil,
        repoOwner: String? = nil,
        repoName: String? = nil,
        defaultWorkingDirectory: String? = nil,
        tags: [String] = [],
        status: ToolStatus = .active,
        riskLevel: RiskLevel = .low,
        installCommand: String? = nil,
        updateCommand: String? = nil,
        uninstallCommand: String? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.defaultWorkingDirectory = defaultWorkingDirectory
        self.tagsData = (try? JSONEncoder().encode(tags)) ?? Data()
        self.statusRaw = status.rawValue
        self.riskLevelRaw = riskLevel.rawValue
        self.installCommand = installCommand
        self.updateCommand = updateCommand
        self.uninstallCommand = uninstallCommand
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
    }
}
