import SwiftUI
import SwiftData

struct ToolEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tool: Tool?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var summary: String = ""
    @State private var sourceType: SourceType = .unknown
    @State private var sourceURL: String = ""
    @State private var localPath: String = ""
    @State private var repoOwner: String = ""
    @State private var repoName: String = ""
    @State private var defaultWorkingDirectory: String = ""
    @State private var tagsText: String = ""
    @State private var status: ToolStatus = .active
    @State private var riskLevel: RiskLevel = .low
    @State private var installCommand: String = ""
    @State private var updateCommand: String = ""
    @State private var uninstallCommand: String = ""
    @State private var notes: String = ""

    private var isEditMode: Bool { tool != nil }
    private var navigationTitle: String { isEditMode ? "编辑工具" : "新建工具" }

    // MARK: - Body

    var body: some View {
        Form {
            basicInfoSection
            sourceSection
            classificationSection
            commandsSection
            notesSection
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            loadTool()
        }
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        Section("基本信息") {
            TextField("名称", text: $name)
            TextField("简介", text: $summary)
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        Section("来源") {
            Picker("来源类型", selection: $sourceType) {
                ForEach(SourceType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }

            TextField("来源地址", text: $sourceURL)

            HStack {
                TextField("本地路径", text: $localPath)
                Button {
                    browseLocalPath()
                } label: {
                    Label("浏览", systemImage: "folder")
                }
            }

            TextField("仓库所有者", text: $repoOwner)
            TextField("仓库名称", text: $repoName)
            TextField("默认工作目录", text: $defaultWorkingDirectory)
            TextField("标签（逗号分隔）", text: $tagsText)
        }
    }

    // MARK: - Classification

    private var classificationSection: some View {
        Section("分类") {
            Picker("状态", selection: $status) {
                ForEach(ToolStatus.allCases) { s in
                    Text(s.label).tag(s)
                }
            }

            Picker("风险等级", selection: $riskLevel) {
                ForEach(RiskLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
        }
    }

    // MARK: - Commands

    private var commandsSection: some View {
        Section("生命周期命令") {
            TextField("安装命令", text: $installCommand)
            TextField("更新命令", text: $updateCommand)
            TextField("卸载命令", text: $uninstallCommand)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("备注") {
            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 200)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Actions

    private func loadTool() {
        guard let tool else { return }
        name = tool.name
        summary = tool.summary
        sourceType = tool.sourceType
        sourceURL = tool.sourceURL ?? ""
        localPath = tool.localPath ?? ""
        repoOwner = tool.repoOwner ?? ""
        repoName = tool.repoName ?? ""
        defaultWorkingDirectory = tool.defaultWorkingDirectory ?? ""
        tagsText = tool.tags.joined(separator: ", ")
        status = tool.status
        riskLevel = tool.riskLevel
        installCommand = tool.installCommand ?? ""
        updateCommand = tool.updateCommand ?? ""
        uninstallCommand = tool.uninstallCommand ?? ""
        notes = tool.notes
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let tool {
            // Edit mode
            tool.name = trimmedName
            tool.summary = summary
            tool.sourceType = sourceType
            tool.sourceURL = sourceURL.isEmpty ? nil : sourceURL
            tool.localPath = localPath.isEmpty ? nil : localPath
            tool.repoOwner = repoOwner.isEmpty ? nil : repoOwner
            tool.repoName = repoName.isEmpty ? nil : repoName
            tool.defaultWorkingDirectory = defaultWorkingDirectory.isEmpty ? nil : defaultWorkingDirectory
            tool.tags = tags
            tool.status = status
            tool.riskLevel = riskLevel
            tool.installCommand = installCommand.isEmpty ? nil : installCommand
            tool.updateCommand = updateCommand.isEmpty ? nil : updateCommand
            tool.uninstallCommand = uninstallCommand.isEmpty ? nil : uninstallCommand
            tool.notes = notes
            tool.updatedAt = Date()
        } else {
            // Create mode
            let newTool = Tool(
                name: trimmedName,
                summary: summary,
                sourceType: sourceType,
                sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                localPath: localPath.isEmpty ? nil : localPath,
                repoOwner: repoOwner.isEmpty ? nil : repoOwner,
                repoName: repoName.isEmpty ? nil : repoName,
                defaultWorkingDirectory: defaultWorkingDirectory.isEmpty ? nil : defaultWorkingDirectory,
                tags: tags,
                status: status,
                riskLevel: riskLevel,
                installCommand: installCommand.isEmpty ? nil : installCommand,
                updateCommand: updateCommand.isEmpty ? nil : updateCommand,
                uninstallCommand: uninstallCommand.isEmpty ? nil : uninstallCommand,
                notes: notes
            )
            modelContext.insert(newTool)
        }

        try? modelContext.save()
        dismiss()
    }

    private func browseLocalPath() {
        let panel = NSOpenPanel()
        panel.title = "选择本地路径"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if !localPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }

}
