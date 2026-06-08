import SwiftUI

struct RunConsoleView: View {
    @Bindable var runner: CommandRunner

    @State private var autoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("控制台输出", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                Button {
                    runner.clear()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)

                if runner.isRunning {
                    Button {
                        runner.stop()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Output area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(runner.stdoutLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .id("stdout_\(index)")
                        }
                        ForEach(Array(runner.stderrLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                                .id("stderr_\(index)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minHeight: 150, maxHeight: 300)
                .onChange(of: runner.stdoutLines.count) {
                    if autoScroll, let lastIndex = runner.stdoutLines.indices.last {
                        withAnimation {
                            proxy.scrollTo("stdout_\(lastIndex)", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: runner.stderrLines.count) {
                    if autoScroll, let lastIndex = runner.stderrLines.indices.last {
                        withAnimation {
                            proxy.scrollTo("stderr_\(lastIndex)", anchor: .bottom)
                        }
                    }
                }
            }

            // Status bar
            HStack(spacing: 12) {
                if runner.isRunning {
                    Label("运行中", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                } else if let code = runner.exitCode {
                    Label("已完成", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(code == 0 ? .green : .red)
                    Text("退出码: \(code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("空闲", systemImage: "circle")
                        .foregroundStyle(.secondary)
                }

                if let duration = runner.durationMs {
                    Text("\(duration) 毫秒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                let totalLines = runner.stdoutLines.count + runner.stderrLines.count
                Text("\(totalLines) 行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
