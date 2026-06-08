import SwiftUI
import SwiftData

@main
struct ToolKeeperApp: App {

    @State private var settings = AppSettings.load()

    // MARK: - SwiftData Container

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Tool.self,
            ToolCommand.self,
            RunHistory.self,
        ])

        let dbURL = URL(fileURLWithPath: AppPaths.database)
        let config = ModelConfiguration(url: dbURL)

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("[ToolKeeperApp] Failed to create persistent container: \(error). Falling back to in-memory.")
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 760)
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建工具") {}
                    .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("导入文件夹") {}
                    .keyboardShortcut("i", modifiers: .command)

                Button("扫描文件夹") {}
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button("设置...") {}
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        // MARK: - Menu Bar Extra

        MenuBarExtra("ToolKeeper", systemImage: "wrench.and.screwdriver") {
            MenuBarContentView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Menu Bar Content View

private struct MenuBarContentView: View {
    @Query(filter: #Predicate<Tool> { $0.lastUsedAt != nil },
           sort: \Tool.lastUsedAt, order: .reverse)
    private var recentTools: [Tool]

    private var lastFive: [Tool] { Array(recentTools.prefix(5)) }

    var body: some View {
        if lastFive.isEmpty {
            Text("暂无最近使用的工具")
        } else {
            ForEach(lastFive) { tool in
                Button {
                    navigateToTool(tool)
                } label: {
                    HStack {
                        Circle()
                            .fill(tool.sourceType.color)
                            .frame(width: 6, height: 6)
                        Text(tool.name)
                            .lineLimit(1)
                        Spacer()
                        if let lastUsed = tool.lastUsedAt {
                            Text(lastUsed, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Divider()
        Button("打开 ToolKeeper") {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func navigateToTool(_ tool: Tool) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: .navigateToTool,
            object: tool.id
        )
    }
}

extension Notification.Name {
    static let navigateToTool = Notification.Name("navigateToTool")
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var hasImported = false

    enum SidebarItem: String, Identifiable, CaseIterable {
        case dashboard
        case tools
        case importView
        case aiTools
        case settings

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .dashboard: return "仪表盘"
            case .tools: return "工具"
            case .importView: return "导入"
            case .aiTools: return "AI 工具"
            case .settings: return "设置"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar"
            case .tools: return "wrench.and.screwdriver"
            case .importView: return "square.and.arrow.down"
            case .aiTools: return "sparkles"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                Label(item.displayName, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 220)
        } detail: {
            switch selectedSidebarItem {
            case .dashboard:
                DashboardView()
            case .tools:
                ToolsListView()
            case .importView:
                ImportWizardView()
            case .aiTools:
                AIToolsView()
            case .settings:
                SettingsView()
            case .none:
                Text("请选择一项")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("ToolKeeper")
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTool)) { notification in
            selectedSidebarItem = .tools
        }
        .onAppear {
            AppPaths.ensureDirectories()
            let settings = AppSettings.load()
            LogStore.cleanupOldLogs(olderThanDays: settings.logRetentionDays)

            if !hasImported {
                hasImported = true
                BatchImporter.importIfNeeded(modelContext: modelContext)
            }
        }
    }
}
