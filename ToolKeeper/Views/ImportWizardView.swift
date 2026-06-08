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
