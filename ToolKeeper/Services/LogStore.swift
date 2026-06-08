import Foundation

enum LogStore {

    /// Deletes log files in AppPaths.logs that are older than the given number of days.
    static func cleanupOldLogs(olderThanDays days: Int) {
        let fm = FileManager.default
        let logsDir = AppPaths.logs

        guard let files = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: logsDir),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 86400))

        for file in files {
            guard let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = attributes.contentModificationDate,
                  modDate < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }

    /// Creates a RunHistory instance. The caller is responsible for inserting it into a ModelContext.
    static func logRun(
        toolID: UUID,
        commandID: UUID,
        command: String,
        cwd: String?,
        exitCode: Int?,
        startedAt: Date,
        stdoutPath: String?,
        stderrPath: String?,
        preview: String
    ) -> RunHistory {
        let entry = RunHistory(
            toolID: toolID,
            commandID: commandID,
            commandSnapshot: command,
            cwd: cwd,
            stdoutLogPath: stdoutPath,
            stderrLogPath: stderrPath,
            outputPreview: preview
        )
        entry.startedAt = startedAt
        entry.finishedAt = Date()
        entry.exitCode = exitCode
        entry.durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        return entry
    }
}
