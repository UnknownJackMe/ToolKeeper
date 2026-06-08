import Foundation
import SwiftData

@Model
final class RunHistory {
    var id: UUID
    var toolID: UUID
    var commandID: UUID
    var startedAt: Date
    var finishedAt: Date?
    var exitCode: Int?
    var durationMs: Int?
    var cwd: String?
    var commandSnapshot: String
    var stdoutLogPath: String?
    var stderrLogPath: String?
    var outputPreview: String

    // Relationships
    var tool: Tool?
    var command: ToolCommand?

    // MARK: - Initializer

    init(
        toolID: UUID,
        commandID: UUID,
        commandSnapshot: String,
        cwd: String? = nil,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        outputPreview: String = ""
    ) {
        self.id = UUID()
        self.toolID = toolID
        self.commandID = commandID
        self.startedAt = Date()
        self.finishedAt = nil
        self.exitCode = nil
        self.durationMs = nil
        self.cwd = cwd
        self.commandSnapshot = commandSnapshot
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.outputPreview = outputPreview
    }
}
