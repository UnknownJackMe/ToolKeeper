import SwiftUI
import SwiftData

struct CommandEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let parentTool: Tool
    let command: ToolCommand?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var commandText: String = ""
    @State private var workingDirectory: String = ""
    @State private var commandDescription: String = ""
    @State private var envVarsText: String = ""
    @State private var requiresConfirmation: Bool = false
    @State private var timeoutSeconds: Int = 120

    private var isEditMode: Bool { command != nil }
    private var navigationTitle: String { isEditMode ? "编辑命令" : "新建命令" }

    // MARK: - Body

    var body: some View {
        Form {
            Section("命令信息") {
                TextField("名称", text: $name)
                TextField("命令", text: $commandText, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.body, design: .monospaced))
                TextField("工作目录", text: $workingDirectory)
                TextField("描述", text: $commandDescription)
            }

            Section("环境变量") {
                TextEditor(text: $envVarsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                Text("每行一个：KEY=value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("选项") {
                Toggle("运行前需要确认", isOn: $requiresConfirmation)

                Stepper(
                    "超时时间：\(timeoutSeconds) 秒",
                    value: $timeoutSeconds,
                    in: 5...3600,
                    step: 5
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitle)
        .frame(minWidth: 450, minHeight: 400)
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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                          || commandText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            loadCommand()
        }
    }

    // MARK: - Actions

    private func loadCommand() {
        guard let command else { return }
        name = command.name
        commandText = command.commandText
        workingDirectory = command.workingDirectory ?? ""
        commandDescription = command.commandDescription
        envVarsText = command.environmentVariables
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
        requiresConfirmation = command.requiresConfirmation
        timeoutSeconds = command.timeoutSeconds
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCommand = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedCommand.isEmpty else { return }

        let envVars = parseEnvVars()

        if let command {
            // Edit mode
            command.name = trimmedName
            command.commandText = trimmedCommand
            command.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
            command.commandDescription = commandDescription
            command.environmentVariables = envVars
            command.requiresConfirmation = requiresConfirmation
            command.timeoutSeconds = timeoutSeconds
            command.updatedAt = Date()
        } else {
            // Create mode
            let newCommand = ToolCommand(
                toolID: parentTool.id,
                name: trimmedName,
                commandText: trimmedCommand,
                workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
                commandDescription: commandDescription,
                environmentVariables: envVars,
                requiresConfirmation: requiresConfirmation,
                timeoutSeconds: timeoutSeconds
            )
            newCommand.tool = parentTool
            modelContext.insert(newCommand)
        }

        try? modelContext.save()
        dismiss()
    }

    private func parseEnvVars() -> [String: String] {
        var result: [String: String] = [:]
        let lines = envVarsText.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let eqIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    result[key] = value
                }
            }
        }
        return result
    }
}
