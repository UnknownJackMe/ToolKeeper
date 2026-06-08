import SwiftUI
import SwiftData

struct AIToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AIToolsViewModel()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                itemList
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 520)
            .navigationTitle("AI 工具")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.scan()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let item = viewModel.selectedItem {
                AIToolDetailView(item: item, viewModel: viewModel, modelContext: modelContext)
            } else {
                ContentUnavailableView(
                    "选择一个 AI 工具",
                    systemImage: "sparkles",
                    description: Text("从列表中选择一个技能、代理或命令以查看详情。")
                )
            }
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.scan()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索 AI 工具...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Picker("来源", selection: $viewModel.selectedSourceType) {
                        Text("全部来源").tag(nil as SourceType?)
                        Text("Claude Code").tag(SourceType.claudeCode as SourceType?)
                        Text("Codex").tag(SourceType.codex as SourceType?)
                    }
                    .frame(maxWidth: .infinity)

                    Picker("类型", selection: $viewModel.selectedItemType) {
                        Text("全部类型").tag(nil as AIToolItemType?)
                        ForEach(AIToolItemType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.label)
                            }
                            .tag(type as AIToolItemType?)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
    }

    // MARK: - Item List

    private var itemList: some View {
        List(selection: $viewModel.selectedItem) {
            if viewModel.filteredItems.isEmpty {
                ContentUnavailableView(
                    "未找到 AI 工具",
                    systemImage: "magnifyingglass",
                    description: Text(viewModel.isLoading ? "正在扫描..." : "请尝试调整搜索条件。")
                )
            } else {
                ForEach(viewModel.filteredItems) { item in
                    NavigationLink(value: item) {
                        AIToolRow(item: item)
                    }
                }
            }
        }
    }
}

// MARK: - AI Tool Row

private struct AIToolRow: View {
    let item: AIToolItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.itemType.icon)
                .font(.title3)
                .foregroundStyle(item.sourceType.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)

                    if item.isSymlink {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !item.isEnabled {
                        Image(systemName: "slash.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    AIBadge(text: item.sourceType.label, color: item.sourceType.color)
                    AIBadge(text: item.itemType.label, color: .secondary)

                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - AI Badge

private struct AIBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - AI Tool Detail View

private struct AIToolDetailView: View {
    let item: AIToolItem
    let viewModel: AIToolsViewModel
    let modelContext: ModelContext

    @State private var showingImportConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: item.itemType.icon)
                            .font(.title)
                            .foregroundStyle(item.sourceType.color)

                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(item.itemType.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Metadata
                GroupBox("元数据") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("来源", value: item.sourceType.label)
                        LabeledContent("类型", value: item.itemType.label)
                        LabeledContent("路径", value: item.sourcePath)
                        if item.isSymlink {
                            LabeledContent("符号链接", value: "是")
                        }
                        LabeledContent("状态", value: item.isEnabled ? "已启用" : "已禁用")
                        if !item.category.isEmpty {
                            LabeledContent("分类", value: item.category)
                        }
                        if let version = item.version {
                            LabeledContent("版本", value: version)
                        }
                        if !item.tags.isEmpty {
                            LabeledContent("标签") {
                                Text(item.tags.joined(separator: ", "))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Content preview
                if let preview = item.contentPreview, !preview.isEmpty {
                    GroupBox("内容预览") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(preview)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        showingImportConfirmation = true
                    } label: {
                        Label("导入为工具", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        viewModel.openInFinder(item.sourcePath)
                    } label: {
                        Label("在 Finder 中显示", systemImage: "folder")
                    }

                    Button {
                        viewModel.toggleEnabled(item)
                    } label: {
                        Label(item.isEnabled ? "禁用" : "启用",
                              systemImage: item.isEnabled ? "slash.circle" : "checkmark.circle")
                    }

                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle(item.name)
        .confirmationDialog(
            "导入为工具",
            isPresented: $showingImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("导入") {
                viewModel.importAsTool(item, modelContext: modelContext)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将「\(item.name)」导入为 ToolKeeper 工具？")
        }
    }
}
