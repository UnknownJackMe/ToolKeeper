import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.load()

    @State private var defaultShell: String = ""
    @State private var defaultToolsDirectory: String = ""
    @State private var logRetentionDays: Int = 30
    @State private var dangerPatternsText: String = ""
    @State private var anthropicBaseURL: String = ""
    @State private var anthropicAPIKey: String = ""
    @State private var anthropicModel: String = ""
    @State private var anthropicUseFullURL: Bool = false

    @State private var showingSaveConfirmation = false
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            appDataSection
            defaultsSection
            logRetentionSection
            dangerPatternsSection
            aiSettingsSection
            actionsSection
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .frame(minWidth: 500, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("设置已保存", isPresented: $showingSaveConfirmation) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("您的设置已成功保存。")
        }
    }

    // MARK: - App Data Section

    private var appDataSection: some View {
        Section("应用数据") {
            LabeledContent("数据路径", value: AppPaths.appSupport)

            HStack {
                Text("设置文件")
                Spacer()
                Text(AppPaths.settings)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button {
                    NSWorkspace.shared.selectFile(
                        AppPaths.settings,
                        inFileViewerRootedAtPath: AppPaths.appSupport
                    )
                } label: {
                    Label("在 Finder 中打开", systemImage: "folder")
                }
            }
        }
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        Section("默认设置") {
            TextField("默认 Shell", text: $defaultShell)

            HStack {
                TextField("默认工具目录", text: $defaultToolsDirectory)
                Button {
                    browseToolsDirectory()
                } label: {
                    Label("浏览", systemImage: "folder")
                }
            }
        }
    }

    // MARK: - Log Retention

    private var logRetentionSection: some View {
        Section("日志保留") {
            Stepper(
                "保留日志 \(logRetentionDays) 天",
                value: $logRetentionDays,
                in: 1...365,
                step: 1
            )
        }
    }

    // MARK: - Danger Patterns

    private var dangerPatternsSection: some View {
        Section("危险模式") {
            TextEditor(text: $dangerPatternsText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100, maxHeight: 200)
                .scrollContentBackground(.hidden)
            Text("每行一个模式。用于将命令分类为高风险。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - AI Settings

    private var aiSettingsSection: some View {
        Section("AI 设置") {
            HStack {
                Text("完整URL")
                Spacer()
                Toggle("完整URL", isOn: $anthropicUseFullURL)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if anthropicUseFullURL {
                TextField("请求地址（如 https://example.com/anthropic/v1/messages）", text: $anthropicBaseURL)
                    .textContentType(.URL)
                Text("完整 URL 模式：直接使用填写的地址发起请求，不拼接 /v1/messages。适用于中转站或自定义端点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("请求地址（如 https://api.anthropic.com）", text: $anthropicBaseURL)
                    .textContentType(.URL)
                Text("自动在请求地址后拼接 /v1/messages。适用于标准 Anthropic API 或兼容端点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SecureField("API KEY", text: $anthropicAPIKey)

            TextField("模型名称", text: $anthropicModel)

            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    Label(isTesting ? "测试中..." : "测试连接",
                          systemImage: isTesting ? "arrow.clockwise" : "bolt.fill")
                }
                .disabled(isTesting || anthropicAPIKey.isEmpty)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("成功") ? .green : .red)
                }
            }

            Text("用于 AI 智能导入功能。支持 Anthropic /v1/messages 格式。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section("操作") {
            Button {
                cleanOldLogs()
            } label: {
                Label("清理旧日志", systemImage: "trash")
            }

            Button {
                resetToDefaults()
            } label: {
                Label("恢复默认设置", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Helpers

    private func loadSettings() {
        defaultShell = settings.defaultShell
        defaultToolsDirectory = settings.defaultToolsDirectory
        logRetentionDays = settings.logRetentionDays
        dangerPatternsText = settings.dangerPatterns.joined(separator: "\n")
        anthropicBaseURL = settings.anthropicBaseURL
        anthropicAPIKey = settings.anthropicAPIKey
        anthropicModel = settings.anthropicModel
        anthropicUseFullURL = settings.anthropicUseFullURL
    }

    private func save() {
        settings.defaultShell = defaultShell
        settings.defaultToolsDirectory = defaultToolsDirectory
        settings.logRetentionDays = logRetentionDays
        settings.dangerPatterns = dangerPatternsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        settings.anthropicBaseURL = anthropicBaseURL
        settings.anthropicAPIKey = anthropicAPIKey
        settings.anthropicModel = anthropicModel
        settings.anthropicUseFullURL = anthropicUseFullURL

        settings.save()
        showingSaveConfirmation = true
    }

    private func browseToolsDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择默认工具目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if !defaultToolsDirectory.isEmpty {
            let expanded = (defaultToolsDirectory as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                panel.directoryURL = URL(fileURLWithPath: expanded)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            defaultToolsDirectory = url.path
        }
    }

    private func cleanOldLogs() {
        let logsPath = AppPaths.logs
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            atPath: logsPath
        ) else { return }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -logRetentionDays,
            to: Date()
        ) ?? Date()

        var removed = 0
        for file in files {
            let filePath = (logsPath as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < cutoff {
                try? fm.removeItem(atPath: filePath)
                removed += 1
            }
        }
    }

    private func resetToDefaults() {
        let defaults = AppSettings()
        defaultShell = defaults.defaultShell
        defaultToolsDirectory = defaults.defaultToolsDirectory
        logRetentionDays = defaults.logRetentionDays
        dangerPatternsText = defaults.dangerPatterns.joined(separator: "\n")
        anthropicBaseURL = defaults.anthropicBaseURL
        anthropicAPIKey = defaults.anthropicAPIKey
        anthropicModel = defaults.anthropicModel
        anthropicUseFullURL = defaults.anthropicUseFullURL
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        let client = AnthropicAPIClient(
            baseURL: anthropicBaseURL,
            apiKey: anthropicAPIKey,
            model: anthropicModel,
            useFullURL: anthropicUseFullURL
        )

        do {
            let response = try await client.send(prompt: "Say 'ok' in one word.")
            testResult = response.contains("ok") ? "连接成功" : "连接成功（响应: \(response.prefix(50))）"
        } catch {
            testResult = "失败: \(error.localizedDescription)"
        }

        isTesting = false
    }
}
