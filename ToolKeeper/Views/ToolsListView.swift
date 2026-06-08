import SwiftUI
import SwiftData

struct ToolsListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tool.name)
    private var allTools: [Tool]

    @State private var viewModel = ToolsViewModel()
    @State private var selectedTool: Tool?
    @State private var showingAddTool = false

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                toolList
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 520)
            .navigationTitle("工具")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTool = true
                    } label: {
                        Label("添加工具", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTool) {
                NavigationStack {
                    ToolEditorView(tool: nil)
                }
            }
        } detail: {
            if let tool = selectedTool {
                ToolDetailView(tool: tool)
            } else {
                ContentUnavailableView(
                    "选择一个工具",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("从列表中选择一个工具以查看详情。")
                )
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索工具...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Filter pickers — two per row so they never over-compress
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Picker("来源", selection: $viewModel.selectedSourceType) {
                        Text("全部来源").tag(nil as SourceType?)
                        ForEach(SourceType.allCases) { type in
                            Text(type.label).tag(type as SourceType?)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Picker("状态", selection: $viewModel.selectedStatus) {
                        Text("全部状态").tag(nil as ToolStatus?)
                        ForEach(ToolStatus.allCases) { status in
                            Text(status.label).tag(status as ToolStatus?)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                GridRow {
                    Picker("风险", selection: $viewModel.selectedRiskLevel) {
                        Text("全部风险").tag(nil as RiskLevel?)
                        ForEach(RiskLevel.allCases) { level in
                            Text(level.label).tag(level as RiskLevel?)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Picker("排序", selection: $viewModel.sortOption) {
                        ForEach(ToolsViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Tag filter
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("按标签过滤（逗号分隔）", text: $viewModel.tagFilterText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    // MARK: - Tool List

    private var toolList: some View {
        List(selection: $selectedTool) {
            if viewModel.filteredTools(allTools).isEmpty {
                ContentUnavailableView(
                    "未找到工具",
                    systemImage: "magnifyingglass",
                    description: Text("请尝试调整搜索条件或过滤器。")
                )
            } else {
                ForEach(viewModel.filteredTools(allTools)) { tool in
                    NavigationLink(value: tool) {
                        ToolRow(tool: tool)
                    }
                }
            }
        }
    }

}

// MARK: - Tool Row

private struct ToolRow: View {
    let tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Name row — takes full width, truncates gracefully
            Text(tool.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Badges row — always on their own line so they never crowd the name
            HStack(spacing: 4) {
                StatusBadge(text: tool.sourceType.label, color: tool.sourceType.color)
                StatusBadge(text: tool.status.label, color: tool.status.color)
                StatusBadge(text: tool.riskLevel.label, color: tool.riskLevel.color)
                Spacer()
            }

            // Summary
            if !tool.summary.isEmpty {
                Text(tool.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Tags
            if !tool.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(tool.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Bottom row: path + command count
            HStack(spacing: 8) {
                if let path = tool.localPath {
                    Label {
                        Text((path as NSString).lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: "folder")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let commands = tool.commands, !commands.isEmpty {
                    Label("\(commands.count)", systemImage: "terminal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lastUsed = tool.lastUsedAt {
                    Text("\(lastUsed, style: .relative) 前")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

}

// MARK: - Status Badge

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
