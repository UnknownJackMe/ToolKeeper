import SwiftUI
import SwiftData

struct ToolDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let tool: Tool

    @State private var viewModel = ToolDetailViewModel()
    @State private var selectedCommand: ToolCommand?
    @State private var showingEditTool = false

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
                if viewModel.commandRunner.isRunning || !viewModel.commandRunner.stdoutLines.isEmpty || !viewModel.commandRunner.stderrLines.isEmpty || viewModel.commandRunner.exitCode != nil {
                    RunConsoleView(runner: viewModel.commandRunner)
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
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                viewModel.deleteTool(tool, modelContext: modelContext)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除「\(tool.name)」吗？此操作不可撤销。")
        }
        .confirmationDialog(
            "高风险命令",
            isPresented: $viewModel.showingHighRiskConfirmation,
            titleVisibility: .visible
        ) {
            Button("仍然运行", role: .destructive) {
                viewModel.confirmRun(modelContext: modelContext, shell: "/bin/zsh")
            }
            Button("取消", role: .cancel) {
                viewModel.pendingCommand = nil
            }
        } message: {
            if let pending = viewModel.pendingCommand {
                Text("此命令被标记为高风险：\n\n\(pending.command.commandText)\n\n是否继续执行？")
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
                Badge(text: tool.sourceType.label, color: tool.sourceType.color)
                Badge(text: tool.status.label, color: tool.status.color)
                Badge(text: tool.riskLevel.label, color: tool.riskLevel.color)
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
                            isRunning: viewModel.commandRunner.isRunning,
                            isSelected: selectedCommand?.id == command.id,
                            onRun: { viewModel.runCommand(command, tool: tool, modelContext: modelContext, shell: "/bin/zsh") },
                            onStop: { viewModel.stopCommand() },
                            onCopy: { viewModel.copyCommand(command) },
                            onEdit: { selectedCommand = command },
                            onDelete: { viewModel.deleteCommand(command, tool: tool, modelContext: modelContext) }
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
                    viewModel.openInFinder(path)
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
                viewModel.revealLogs()
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
                viewModel.showingDeleteConfirmation = true
            } label: {
                Label("删除工具", systemImage: "trash")
            }
        }
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: ToolCommand
    let isRunning: Bool
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
                .disabled(isRunning)
                .help("运行命令")

                Button(action: onStop) {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!isRunning)
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
