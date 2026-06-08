import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tool.createdAt, order: .reverse)
    private var allTools: [Tool]

    @Query(filter: #Predicate<Tool> { $0.lastUsedAt != nil },
           sort: \Tool.lastUsedAt, order: .reverse)
    private var recentlyUsedTools: [Tool]

    @Query(sort: \RunHistory.startedAt, order: .reverse)
    private var recentRuns: [RunHistory]

    // MARK: - Computed

    private var totalCount: Int { allTools.count }
    private var activeCount: Int { allTools.filter { $0.status == .active }.count }
    private var archivedCount: Int { allTools.filter { $0.status == .archived }.count }
    private var brokenCount: Int { allTools.filter { $0.status == .broken }.count }
    private var highRiskCount: Int { allTools.filter { $0.riskLevel == .high }.count }

    private var lastFiveUsed: [Tool] { Array(recentlyUsedTools.prefix(5)) }
    private var lastTenRuns: [RunHistory] { Array(recentRuns.prefix(10)) }

    private var sourceDistribution: [(SourceType, Int)] {
        Dictionary(grouping: allTools) { $0.sourceType }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    private var riskDistribution: [(RiskLevel, Int)] {
        Dictionary(grouping: allTools) { $0.riskLevel }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsRow
                middleRow
                recentRunsCard
            }
            .padding(20)
        }
        .navigationTitle("仪表盘")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "工具总数", value: "\(totalCount)",
                     icon: "wrench.and.screwdriver.fill", color: .blue)
            StatCard(title: "活跃", value: "\(activeCount)",
                     icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "已归档", value: "\(archivedCount)",
                     icon: "archivebox.fill", color: .orange)
            StatCard(title: "已损坏", value: "\(brokenCount)",
                     icon: "exclamationmark.triangle.fill", color: .red)
            StatCard(title: "高风险", value: "\(highRiskCount)",
                     icon: "shield.lefthalf.filled", color: .purple)
        }
    }

    // MARK: - Middle Row

    private var middleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            recentlyUsedCard
            distributionCard
                .frame(width: 260)
        }
    }

    // MARK: - Recently Used Card

    private var recentlyUsedCard: some View {
        DashboardCard(title: "最近使用", icon: "clock.fill") {
            if lastFiveUsed.isEmpty {
                emptyState(text: "暂无最近使用的工具")
            } else {
                VStack(spacing: 0) {
                    ForEach(lastFiveUsed) { tool in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(tool.sourceType.color)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.name)
                                    .font(.system(.body, weight: .medium))
                                    .lineLimit(1)
                                if !tool.summary.isEmpty {
                                    Text(tool.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if let lastUsed = tool.lastUsedAt {
                                    Text(lastUsed, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(tool.sourceType.label)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(tool.sourceType.color.opacity(0.15))
                                    .foregroundStyle(tool.sourceType.color)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)

                        if tool.id != lastFiveUsed.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Distribution Card

    private var distributionCard: some View {
        DashboardCard(title: "工具分布", icon: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 14) {
                distributionSection(
                    title: "来源类型",
                    items: sourceDistribution.prefix(6).map { ($0.0.label, $0.0.color, $0.1) }
                )

                Divider()

                distributionSection(
                    title: "风险等级",
                    items: riskDistribution.map { ($0.0.label + "风险", $0.0.color, $0.1) }
                )
            }
        }
    }

    private func distributionSection(title: String, items: [(String, Color, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(items, id: \.0) { label, color, count in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption)
                        .frame(width: 56, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.75))
                            .frame(
                                width: totalCount > 0
                                    ? max(4, geo.size.width * CGFloat(count) / CGFloat(totalCount))
                                    : 0
                            )
                    }
                    .frame(height: 10)

                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Recent Runs Card

    private var recentRunsCard: some View {
        DashboardCard(title: "最近运行", icon: "terminal.fill") {
            if lastTenRuns.isEmpty {
                emptyState(text: "暂无运行记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(lastTenRuns) { run in
                        HStack(spacing: 10) {
                            Group {
                                if let code = run.exitCode {
                                    Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(code == 0 ? .green : .red)
                                } else {
                                    Image(systemName: "circle.dotted")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.footnote)
                            .frame(width: 16)

                            Text(run.commandSnapshot)
                                .font(.system(.footnote, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if let duration = run.durationMs {
                                Text("\(duration) ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 64, alignment: .trailing)
                                    .monospacedDigit()
                            }

                            Text(run.startedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 6)

                        if run.id != lastTenRuns.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dashboard Card

private struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
