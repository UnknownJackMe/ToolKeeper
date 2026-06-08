import SwiftUI
import SwiftData

struct ImportWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ImportTab = .localFolder

    enum ImportTab: String, CaseIterable, Identifiable {
        case localFolder = "本地文件夹"
        case githubURL = "GitHub 地址"
        case scanFolder = "扫描文件夹"
        case aiImport = "AI 导入"

        var id: String { rawValue }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LocalFolderTab(modelContext: modelContext)
                .tabItem { Label("本地文件夹", systemImage: "folder") }
                .tag(ImportTab.localFolder)

            GitHubURLTab(modelContext: modelContext)
                .tabItem { Label("GitHub 地址", systemImage: "globe") }
                .tag(ImportTab.githubURL)

            ScanFolderTab(modelContext: modelContext)
                .tabItem { Label("扫描文件夹", systemImage: "doc.text.magnifyingglass") }
                .tag(ImportTab.scanFolder)

            AIImportTab(modelContext: modelContext)
                .tabItem { Label("AI 导入", systemImage: "sparkles") }
                .tag(ImportTab.aiImport)
        }
        .formStyle(.grouped)
        .frame(minWidth: 550, minHeight: 450)
        .navigationTitle("导入工具")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Local Folder Tab

private struct LocalFolderTab: View {
    let modelContext: ModelContext

    @State private var selectedFolderPath: String?
    @State private var analysisResult: FolderAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("从本地文件夹导入工具。")
                .font(.headline)

            HStack {
                Button {
                    pickFolder()
                } label: {
                    Label("选择文件夹...", systemImage: "folder.badge.plus")
                }

                if let path = selectedFolderPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if isAnalyzing {
                ProgressView("正在分析文件夹...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if let result = analysisResult {
                Divider()
                GroupBox("分析结果") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let gitURL = result.gitOriginURL {
                            LabeledContent("Git 来源", value: gitURL)
                        }
                        if let readme = result.readmeSummary, !readme.isEmpty {
                            LabeledContent("README") {
                                Text(readme)
                                    .font(.caption)
                                    .lineLimit(4)
                            }
                        }
                        if !result.packageScripts.isEmpty {
                            LabeledContent("npm 脚本") {
                                VStack(alignment: .leading) {
                                    ForEach(result.packageScripts, id: \.self) { script in
                                        Text(script)
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                }
                            }
                        }
                        if !result.makefileTargets.isEmpty {
                            LabeledContent("Makefile 目标") {
                                VStack(alignment: .leading) {
                                    ForEach(result.makefileTargets, id: \.self) { target in
                                        Text(target)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        if !result.pyprojectScripts.isEmpty {
                            LabeledContent("pyproject 脚本") {
                                VStack(alignment: .leading) {
                                    ForEach(result.pyprojectScripts, id: \.self) { script in
                                        Text(script)
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                }
                            }
                        }
                        if let cargo = result.cargoPackageName {
                            LabeledContent("Cargo 包名", value: cargo)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    importFromLocalFolder(result)
                } label: {
                    Label("导入为工具", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择工具文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolderPath = url.path
            analyzeFolder(at: url.path)
        }
    }

    private func analyzeFolder(at path: String) {
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil

        let result = ImportAnalyzer.analyzeFolder(at: path)
        analysisResult = result
        isAnalyzing = false
    }

    private func importFromLocalFolder(_ result: FolderAnalysis) {
        guard let path = selectedFolderPath else { return }

        let tool = Tool(
            name: (path as NSString).lastPathComponent,
            summary: result.readmeSummary ?? "",
            sourceType: result.detectedSourceType,
            sourceURL: result.gitOriginURL,
            localPath: path,
            tags: []
        )

        // Auto-create commands from detected scripts/targets
        for script in result.packageScripts {
            let cmd = ToolCommand(
                toolID: tool.id,
                name: "npm: \(script)",
                commandText: "npm run \(script)",
                commandDescription: "运行 npm 脚本 \(script)",
                requiresConfirmation: false
            )
            tool.commands = (tool.commands ?? []) + [cmd]
        }
        for target in result.makefileTargets {
            let cmd = ToolCommand(
                toolID: tool.id,
                name: "make: \(target)",
                commandText: "make \(target)",
                commandDescription: "运行 make 目标 \(target)",
                requiresConfirmation: false
            )
            tool.commands = (tool.commands ?? []) + [cmd]
        }

        modelContext.insert(tool)
        try? modelContext.save()
    }
}

// MARK: - GitHub URL Tab

private struct GitHubURLTab: View {
    let modelContext: ModelContext

    @State private var githubURL = ""
    @State private var parsedOwner: String?
    @State private var parsedRepo: String?
    @State private var isCloning = false
    @State private var cloneProgress = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("从 GitHub 仓库导入工具。")
                .font(.headline)

            HStack {
                TextField("GitHub 地址（如 https://github.com/owner/repo）", text: $githubURL)
                    .textFieldStyle(.roundedBorder)
                Button {
                    parseURL()
                } label: {
                    Label("解析", systemImage: "arrow.right.circle")
                }
                .disabled(githubURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if let owner = parsedOwner, let repo = parsedRepo {
                Divider()
                GroupBox("解析结果") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("所有者", value: owner)
                        LabeledContent("仓库", value: repo)
                        LabeledContent("地址", value: "https://github.com/\(owner)/\(repo)")
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 12) {
                    Button {
                        importGitHubTool(owner: owner, repo: repo)
                    } label: {
                        Label("导入为工具", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        cloneToFolder(owner: owner, repo: repo)
                    } label: {
                        Label("克隆到文件夹...", systemImage: "arrow.down.circle")
                    }
                }

                if isCloning {
                    ProgressView(cloneProgress)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func parseURL() {
        errorMessage = nil
        parsedOwner = nil
        parsedRepo = nil

        if let (owner, repo) = GitParser.parseGitHubOwnerRepo(from: githubURL) {
            parsedOwner = owner
            parsedRepo = repo
        } else {
            errorMessage = "无法解析 GitHub 地址。格式应为：https://github.com/owner/repo"
        }
    }

    private func importGitHubTool(owner: String, repo: String) {
        let tool = Tool(
            name: repo,
            summary: "",
            sourceType: .github,
            sourceURL: "https://github.com/\(owner)/\(repo)",
            repoOwner: owner,
            repoName: repo,
            tags: []
        )
        modelContext.insert(tool)
        try? modelContext.save()
    }

    private func cloneToFolder(owner: String, repo: String) {
        let panel = NSOpenPanel()
        panel.title = "选择克隆目标目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let targetDir = panel.url else { return }

        isCloning = true
        cloneProgress = "正在克隆 https://github.com/\(owner)/\(repo)..."

        let cloneURL = "https://github.com/\(owner)/\(repo)"
        let destination = targetDir.appendingPathComponent(repo).path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", cloneURL, destination]

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                isCloning = false
                cloneProgress = ""
                if process.terminationStatus == 0 {
                    let tool = Tool(
                        name: repo,
                        summary: "",
                        sourceType: .github,
                        sourceURL: cloneURL,
                        localPath: destination,
                        repoOwner: owner,
                        repoName: repo,
                        tags: []
                    )
                    modelContext.insert(tool)
                    try? modelContext.save()
                } else {
                    errorMessage = "克隆失败，退出码 \(process.terminationStatus)"
                }
            }
        }

        do {
            try process.run()
        } catch {
            isCloning = false
            errorMessage = "启动 git 失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - Scan Folder Tab

private struct ScanFolderTab: View {
    let modelContext: ModelContext

    @State private var rootFolderPath: String?
    @State private var scanResults: [ScanResult] = []
    @State private var selectedIndices: Set<Int> = []
    @State private var isScanning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("扫描根目录以发现多个工具。")
                .font(.headline)

            HStack {
                Button {
                    pickRootFolder()
                } label: {
                    Label("选择根目录...", systemImage: "folder.badge.plus")
                }

                if let path = rootFolderPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if isScanning {
                ProgressView("正在扫描文件夹...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if !scanResults.isEmpty {
                Divider()

                HStack {
                    Text("发现 \(scanResults.count) 个潜在工具")
                        .font(.headline)
                    Spacer()
                    Button("全选") {
                        selectedIndices = Set(scanResults.indices)
                    }
                    Button("取消全选") {
                        selectedIndices.removeAll()
                    }
                }

                List {
                    ForEach(Array(scanResults.enumerated()), id: \.offset) { index, result in
                        HStack {
                            Toggle(
                                result.name,
                                isOn: Binding(
                                    get: { selectedIndices.contains(index) },
                                    set: { isOn in
                                        if isOn {
                                            selectedIndices.insert(index)
                                        } else {
                                            selectedIndices.remove(index)
                                        }
                                    }
                                )
                            )
                            Spacer()
                            Text(result.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(resultTypeLabel(result.type))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(resultTypeColor(result.type).opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(minHeight: 150)

                Button {
                    importSelected()
                } label: {
                    Label("导入选中项（\(selectedIndices.count)）", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndices.isEmpty)
            }

            Spacer()
        }
        .padding()
    }

    private func resultTypeLabel(_ type: ScanResultType) -> String {
        switch type {
        case .script: return "脚本"
        case .config: return "配置"
        case .project: return "项目"
        }
    }

    private func resultTypeColor(_ type: ScanResultType) -> Color {
        switch type {
        case .script: return .blue
        case .config: return .orange
        case .project: return .green
        }
    }

    private func pickRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择要扫描的根目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            rootFolderPath = url.path
            scanFolder(at: url.path)
        }
    }

    private func scanFolder(at path: String) {
        isScanning = true
        errorMessage = nil
        scanResults = []
        selectedIndices = []

        let results = FolderScanner.scanFolder(at: path)
        scanResults = results
        selectedIndices = Set(results.indices)
        isScanning = false
    }

    private func importSelected() {
        let toImport = selectedIndices.map { scanResults[$0] }
        for result in toImport {
            let analysis = ImportAnalyzer.analyzeFolder(at: (result.path as NSString).deletingLastPathComponent)
            let tool = Tool(
                name: result.name,
                summary: analysis.readmeSummary ?? "",
                sourceType: analysis.detectedSourceType,
                sourceURL: analysis.gitOriginURL,
                localPath: result.path,
                tags: []
            )
            modelContext.insert(tool)
        }
        try? modelContext.save()
    }
}

// MARK: - AI Import Tab

private struct AIImportTab: View {
    let modelContext: ModelContext

    @State private var viewModel = AIImportViewModel()
    @State private var editingIndex: Int?
    @State private var editingSuggestion: AIToolSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if viewModel.suggestions.isEmpty && !viewModel.isAnalyzing {
                directoryPickerSection
            }

            if viewModel.isAnalyzing {
                analyzingSection
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if !viewModel.suggestions.isEmpty && !viewModel.isAnalyzing {
                resultsSection
            }

            if viewModel.importedCount > 0 {
                importedSection
            }

            Spacer()
        }
        .padding()
        .sheet(item: $editingSuggestion) { suggestion in
            NavigationStack {
                AISuggestionEditView(suggestion: suggestion) { updated in
                    if let index = editingIndex {
                        viewModel.updateSuggestion(at: index, with: updated)
                    }
                    editingSuggestion = nil
                    editingIndex = nil
                } onCancel: {
                    editingSuggestion = nil
                    editingIndex = nil
                }
            }
            .frame(minWidth: 500, minHeight: 450)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Text("使用 AI 递归分析目录，自动识别并导入工具。")
            .font(.headline)
    }

    // MARK: - Directory Picker

    private var directoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    viewModel.pickDirectory()
                } label: {
                    Label("选择目录...", systemImage: "folder.badge.plus")
                }

                if !viewModel.directoryPath.isEmpty {
                    Text(viewModel.directoryPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }

            if !viewModel.directoryPath.isEmpty {
                Button {
                    viewModel.analyzeDirectory()
                } label: {
                    Label("开始 AI 分析", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.directoryPath.isEmpty)
            }
        }
    }

    // MARK: - Analyzing

    private var analyzingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在扫描目录并调用 AI 分析，请稍候...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("AI 识别到 \(viewModel.suggestions.count) 个工具")
                    .font(.headline)
                Spacer()
                Button("全选") { viewModel.selectAll() }
                Button("取消全选") { viewModel.deselectAll() }
                Button("重新分析") { viewModel.reset() }
            }

            List {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    HStack(spacing: 10) {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.selectedIndices.contains(index) },
                                set: { _ in viewModel.toggleSelection(index) }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(suggestion.name)
                                    .font(.system(.body, weight: .medium))

                                Text(suggestion.importType == "aiTool" ? "AI 工具" : "工具")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        (suggestion.importType == "aiTool"
                                            ? Color.indigo
                                            : Color.blue
                                        ).opacity(0.15)
                                    )
                                    .foregroundStyle(
                                        suggestion.importType == "aiTool"
                                            ? Color.indigo
                                            : Color.blue
                                    )
                                    .clipShape(Capsule())

                                Text(suggestion.sourceType)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            if !suggestion.summary.isEmpty {
                                Text(suggestion.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            HStack(spacing: 4) {
                                if !suggestion.tags.isEmpty {
                                    ForEach(suggestion.tags.prefix(4), id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }

                                if !suggestion.commands.isEmpty {
                                    Text("\(suggestion.commands.count) 个命令")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let path = suggestion.localPath {
                                Text(path)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            editingIndex = index
                            editingSuggestion = suggestion
                        } label: {
                            Label("查看与编辑", systemImage: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 150)

            Button {
                viewModel.importSelected(modelContext: modelContext)
            } label: {
                Label("导入选中项（\(viewModel.selectedIndices.count)）",
                      systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasSelection)
        }
    }

    // MARK: - Imported

    private var importedSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("成功导入 \(viewModel.importedCount) 个工具")
                .font(.subheadline)
        }
        .padding(.top, 4)
    }
}

// MARK: - AI Suggestion Edit View

private struct AISuggestionEditView: View {
    let suggestion: AIToolSuggestion
    let onSave: (AIToolSuggestion) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var summary: String
    @State private var sourceType: String
    @State private var sourceURL: String
    @State private var localPath: String
    @State private var tagsText: String
    @State private var importType: String
    @State private var commands: [SuggestedCommand]

    init(suggestion: AIToolSuggestion, onSave: @escaping (AIToolSuggestion) -> Void, onCancel: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: suggestion.name)
        _summary = State(initialValue: suggestion.summary)
        _sourceType = State(initialValue: suggestion.sourceType)
        _sourceURL = State(initialValue: suggestion.sourceURL ?? "")
        _localPath = State(initialValue: suggestion.localPath ?? "")
        _tagsText = State(initialValue: suggestion.tags.joined(separator: ", "))
        _importType = State(initialValue: suggestion.importType)
        _commands = State(initialValue: suggestion.commands)
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("名称", text: $name)
                TextField("摘要", text: $summary)
                Picker("来源类型", selection: $sourceType) {
                    Text("GitHub").tag("github")
                    Text("本地").tag("local")
                    Text("脚本").tag("script")
                    Text("Homebrew").tag("homebrew")
                    Text("npm").tag("npm")
                    Text("pip").tag("pip")
                    Text("Claude Code").tag("claudeCode")
                    Text("Codex").tag("codex")
                    Text("未知").tag("unknown")
                }
                TextField("来源 URL", text: $sourceURL)
                TextField("本地路径", text: $localPath)
                TextField("标签（逗号分隔）", text: $tagsText)
                Picker("导入类型", selection: $importType) {
                    Text("工具").tag("tool")
                    Text("AI 工具").tag("aiTool")
                }
            }

            Section("命令 (\(commands.count))") {
                ForEach(Array(commands.enumerated()), id: \.element.id) { index, cmd in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("命令名称", text: Binding(
                            get: { commands[index].name },
                            set: { commands[index].name = $0 }
                        ))
                        .font(.system(.body, weight: .medium))

                        TextField("命令文本", text: Binding(
                            get: { commands[index].commandText },
                            set: { commands[index].commandText = $0 }
                        ))
                        .font(.system(.caption, design: .monospaced))

                        TextField("描述", text: Binding(
                            get: { commands[index].description ?? "" },
                            set: { commands[index].description = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    commands.remove(atOffsets: indexSet)
                }

                Button {
                    commands.append(SuggestedCommand(name: "", commandText: "", description: nil))
                } label: {
                    Label("添加命令", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("查看与编辑")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    var updated = suggestion
                    updated.name = name
                    updated.summary = summary
                    updated.sourceType = sourceType
                    updated.sourceURL = sourceURL.isEmpty ? nil : sourceURL
                    updated.localPath = localPath.isEmpty ? nil : localPath
                    updated.tags = tagsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    updated.importType = importType
                    updated.commands = commands
                    onSave(updated)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
