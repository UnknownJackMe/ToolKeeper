import Foundation
import SwiftData

@Model
final class ToolCommand {
    var id: UUID
    var toolID: UUID
    var name: String
    var commandText: String
    var workingDirectory: String?
    var commandDescription: String
    var envVarsData: Data
    var requiresConfirmation: Bool
    var timeoutSeconds: Int
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    var tool: Tool?

    @Relationship(deleteRule: .cascade)
    var runHistories: [RunHistory]?

    // MARK: - Computed Properties

    var environmentVariables: [String: String] {
        get {
            guard !envVarsData.isEmpty else { return [:] }
            do {
                return try JSONDecoder().decode([String: String].self, from: envVarsData)
            } catch {
                return [:]
            }
        }
        set {
            do {
                envVarsData = try JSONEncoder().encode(newValue)
            } catch {
                envVarsData = Data()
            }
        }
    }

    // MARK: - Initializer

    init(
        toolID: UUID,
        name: String,
        commandText: String,
        workingDirectory: String? = nil,
        commandDescription: String = "",
        environmentVariables: [String: String] = [:],
        requiresConfirmation: Bool = false,
        timeoutSeconds: Int = 120
    ) {
        self.id = UUID()
        self.toolID = toolID
        self.name = name
        self.commandText = commandText
        self.workingDirectory = workingDirectory
        self.commandDescription = commandDescription
        self.envVarsData = (try? JSONEncoder().encode(environmentVariables)) ?? Data()
        self.requiresConfirmation = requiresConfirmation
        self.timeoutSeconds = timeoutSeconds
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
