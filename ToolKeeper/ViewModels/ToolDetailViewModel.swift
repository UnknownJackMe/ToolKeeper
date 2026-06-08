import Foundation
import SwiftUI
import AppKit
import SwiftData

@Observable
@MainActor
final class ToolDetailViewModel {

    // MARK: - Properties

    var commandRunner = CommandRunner()
    var showingCommandEditor: Bool = false
    var editingCommand: ToolCommand? = nil
    var showingDeleteConfirmation: Bool = false
    var showingHighRiskConfirmation: Bool = false
    var pendingCommand: (tool: Tool, command: ToolCommand)? = nil

    // MARK: - Command Execution

    func runCommand(_ command: ToolCommand, tool: Tool, modelContext: ModelContext, shell: String) {
        let risk = RiskClassifier.classify(command: command.commandText)

        if risk == .high {
            pendingCommand = (tool: tool, command: command)
            showingHighRiskConfirmation = true
            return
        }

        executeCommand(command, tool: tool, modelContext: modelContext, shell: shell)
    }

    func confirmRun(modelContext: ModelContext, shell: String) {
        guard let pending = pendingCommand else { return }
        showingHighRiskConfirmation = false
        executeCommand(pending.command, tool: pending.tool, modelContext: modelContext, shell: shell)
        pendingCommand = nil
    }

    func stopCommand() {
        commandRunner.stop()
    }

    // MARK: - Clipboard

    func copyCommand(_ command: ToolCommand) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command.commandText, forType: .string)
    }

    // MARK: - Deletion

    func deleteCommand(_ command: ToolCommand, tool: Tool, modelContext: ModelContext) {
        tool.commands?.removeAll { $0.id == command.id }
        modelContext.delete(command)
        try? modelContext.save()
    }

    func deleteTool(_ tool: Tool, modelContext: ModelContext) {
        modelContext.delete(tool)
        try? modelContext.save()
    }

    // MARK: - External Actions

    func openInFinder(_ path: String) {
        let expanded = AppPaths.expand(path)
        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    func openSourceURL(_ url: String) {
        guard let urlObj = URL(string: url) else { return }
        NSWorkspace.shared.open(urlObj)
    }

    func revealLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: AppPaths.logs))
    }

    // MARK: - Private Helpers

    private func executeCommand(_ command: ToolCommand, tool: Tool, modelContext: ModelContext, shell: String) {
        let cwd = command.workingDirectory
            ?? tool.defaultWorkingDirectory
            ?? FileManager.default.currentDirectoryPath

        let startTime = Date()

        commandRunner.run(
            command: command.commandText,
            workingDirectory: cwd,
            shell: shell,
            timeout: command.timeoutSeconds
        ) { [weak self] exitCode in
            guard let self else { return }

            let history = LogStore.logRun(
                toolID: tool.id,
                commandID: command.id,
                command: command.commandText,
                cwd: cwd,
                exitCode: exitCode,
                startedAt: startTime,
                stdoutPath: nil,
                stderrPath: nil,
                preview: self.commandRunner.stdoutLines.suffix(5).joined(separator: "\n")
            )

            modelContext.insert(history)
            tool.lastUsedAt = Date()
            tool.updatedAt = Date()
            try? modelContext.save()
        }
    }
}
