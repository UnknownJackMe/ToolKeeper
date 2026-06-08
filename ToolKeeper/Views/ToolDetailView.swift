import SwiftUI
import SwiftData

struct ToolDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let tool: Tool

    @State private var selectedCommand: ToolCommand?
    @State private var showingEditTool = false
    @State private var showingDeleteConfirmation = false
    @State private var showingHighRiskConfirmation = false
    @State private var pendingCommand: ToolCommand?
    @State private var activeRunner: CommandRunner?

    // MARK: - Computed

    private var sortedCommands: [ToolCommand] {
        (tool.commands ?? []).sorted { $0.name < $1.name }
    }

    private var recentRuns: [RunHistory] {
        ((tool.runHistories ?? []) as [RunHistory])
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(20)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                infoSection
                commandsSection
                if let runner = activeRunner {
                    RunConsoleView(runner: runner)
                }
                recentRunsSection
                notesSection
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle(tool.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditTool = true
                } label: {
                    Label("编辑工具", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditTool) {
            NavigationStack {
                ToolEditorView(tool: tool)
            }
        }
        .confirmationDialog(
            "删除工具",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deleteTool()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除「\(tool.name)」吗？此操作不可撤销。")
        }
        .confirmationDialog(
            "高风险命令",
            isPresented: $showingHighRiskConfirmation,
            titleVisibility: .visible
        ) {
            Button("仍然运行", role: .destructive) {
                if let cmd = pendingCommand {
                    executeCommand(cmd)
                }
            }
            Button("取消", role: .cancel) {
                pendingCommand = nil
            }
        } message: {
            if let cmd = pendingCommand {
                Text("此命令被标记为高风险：\n\n\(cmd.commandText)\n\n是否继续执行？")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tool.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }

            if !tool.summary.isEmpty {
                Text(tool.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Badge(text: sourceTypeLabel(tool.sourceType), color: .blue)
                Badge(text: statusLabel(tool.status), color: statusColor)
                Badge(text: riskLevelLabel(tool.riskLevel), color: riskColor)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        GroupBox("基本信息") {
            VStack(alignment: .leading, spacing: 8) {
                if let sourceURL = tool.sourceURL, !sourceURL.isEmpty {
                    LabeledContent("来源地址") {
                        Link(destination: URL(string: sourceURL) ?? URL(string: "about:blank")!) {
                            Text(sourceURL)
                                .lineLimit(1)
                        }
                    }
                }

                if let localPath = tool.localPath, !localPath.isEmpty {
                    LabeledContent("本地路径", value: localPath)
                }

                if let owner = tool.repoOwner, !owner.isEmpty,
                   let name = tool.repoName, !name.isEmpty {
                    LabeledContent("仓库", value: "\(owner)/\(name)")
                }

                if let cwd = tool.defaultWorkingDirectory, !cwd.isEmpty {
                    LabeledContent("工作目录", value: cwd)
                }

                if !tool.tags.isEmpty {
                    LabeledContent("标签") {
                        Text(tool.tags.joined(separator: ", "))
                    }
                }

                if let install = tool.installCommand, !install.isEmpty {
                    LabeledContent("安装命令") {
                        Text(install)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                if let update = tool.updateCommand, !update.isEmpty {
                    LabeledContent("更新命令") {
                        Text(update)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                if let uninstall = tool.uninstallCommand, !uninstall.isEmpty {
                    LabeledContent("卸载命令") {
                        Text(uninstall)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Commands Section

    private var commandsSection: some View {
        GroupBox("命令") {
            if sortedCommands.isEmpty {
                Text("暂未定义命令。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedCommands) { command in
                        CommandRow(
                            command: command,
                            isSelected: selectedCommand?.id == command.id,
                            onRun: { runCommand(command) },
                            onStop: { stopCommand() },
                            onCopy: { copyCommand(command) },
                            onEdit: { selectedCommand = command },
                            onDelete: { deleteCommand(command) }
                        )
                        if command.id != sortedCommands.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Runs

    private var recentRunsSection: some View {
        GroupBox("最近运行") {
            if recentRuns.isEmpty {
                Text("暂无运行记录。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(recentRuns) { run in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.commandSnapshot)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                if let cwd = run.cwd {
                                    Text(cwd)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(run.startedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    if let duration = run.durationMs {
                                        Text("\(duration)毫秒")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let code = run.exitCode {
                                        Text("退出码 \(code)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(code == 0 ? .green : .red)
                                    } else {
                                        Text("运行中")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if run.id != recentRuns.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        GroupBox("备注") {
            TextEditor(text: Binding(
                get: { tool.notes },
                set: { tool.notes = $0; tool.updatedAt = Date() }
            ))
            .font(.body)
            .frame(minHeight: 100, maxHeight: 200)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            if let path = tool.localPath, !path.isEmpty {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                } label: {
                    Label("在 Finder 中打开", systemImage: "folder")
                }
            }

            if let urlStr = tool.sourceURL, !urlStr.isEmpty,
               let url = URL(string: urlStr) {
                Link(destination: url) {
                    Label("打开来源地址", systemImage: "globe")
                }
            }

            Button {
                revealLogs()
            } label: {
                Label("查看日志", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                showingEditTool = true
            } label: {
                Label("编辑工具", systemImage: "pencil")
            }

            Spacer()

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("删除工具", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch tool.status {
        case .active: return .green
        case .archived: return .orange
        case .broken: return .red
        case .unknown: return .gray
        }
    }

    private var riskColor: Color {
        switch tool.riskLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }

    private func sourceTypeLabel(_ type: SourceType) -> String {
        switch type {
        case .github: return "GitHub"
        case .local: return "本地"
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        case .pip: return "pip"
        case .binary: return "二进制"
        case .script: return "脚本"
        case .website: return "网站"
        case .unknown: return "未知"
        }
    }

    private func statusLabel(_ status: ToolStatus) -> String {
        switch status {
        case .active: return "活跃"
        case .archived: return "已归档"
        case .broken: return "已损坏"
        case .unknown: return "未知"
        }
    }

    private func riskLevelLabel(_ level: RiskLevel) -> String {
        switch level {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    private func runCommand(_ command: ToolCommand) {
        let risk = RiskClassifier.classify(command: command.commandText)
        if risk == .high || command.requiresConfirmation {
            pendingCommand = command
            showingHighRiskConfirmation = true
            return
        }
        executeCommand(command)
    }

    private func executeCommand(_ command: ToolCommand) {
        pendingCommand = nil
        let runner = CommandRunner()
        activeRunner = runner
        let cwd = command.workingDirectory ?? tool.defaultWorkingDirectory
        runner.run(
            command: command.commandText,
            workingDirectory: cwd,
            shell: "/bin/zsh",
            timeout: command.timeoutSeconds
        ) { [weak runner] exitCode in
            let history = LogStore.logRun(
                toolID: tool.id,
                commandID: command.id,
                command: command.commandText,
                cwd: cwd,
                exitCode: exitCode,
                startedAt: Date(),
                stdoutPath: nil,
                stderrPath: nil,
                preview: runner?.stdoutLines.suffix(5).joined(separator: "\n") ?? ""
            )
            modelContext.insert(history)
            tool.lastUsedAt = Date()
            tool.updatedAt = Date()
            try? modelContext.save()
        }
    }

    private func stopCommand() {
        activeRunner?.stop()
    }

    private func copyCommand(_ command: ToolCommand) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command.commandText, forType: .string)
    }

    private func deleteCommand(_ command: ToolCommand) {
        modelContext.delete(command)
        try? modelContext.save()
    }

    private func deleteTool() {
        modelContext.delete(tool)
        try? modelContext.save()
    }

    private func revealLogs() {
        let logsPath = AppPaths.logs
        NSWorkspace.shared.open(URL(fileURLWithPath: logsPath))
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: ToolCommand
    let isSelected: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.headline)
                Text(command.commandText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !command.commandDescription.isEmpty {
                    Text(command.commandDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: onRun) {
                    Label("运行", systemImage: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("运行命令")

                Button(action: onStop) {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("停止命令")

                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制命令文本")

                Button(action: onEdit) {
                    Label("编辑", systemImage: "pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑命令")

                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除命令")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Badge

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
