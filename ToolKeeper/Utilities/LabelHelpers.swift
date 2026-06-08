import SwiftUI

// MARK: - SourceType

extension SourceType {
    var label: String {
        switch self {
        case .github:      return "GitHub"
        case .local:       return "本地"
        case .homebrew:    return "Homebrew"
        case .npm:         return "npm"
        case .pip:         return "pip"
        case .binary:      return "二进制"
        case .script:      return "脚本"
        case .website:     return "网站"
        case .unknown:     return "未知"
        case .claudeCode:  return "Claude Code"
        case .codex:       return "Codex"
        }
    }

    var color: Color {
        switch self {
        case .github:      return .purple
        case .local:       return .blue
        case .homebrew:    return .orange
        case .npm:         return .red
        case .pip:         return .yellow
        case .binary:      return .gray
        case .script:      return .teal
        case .website:     return .cyan
        case .unknown:     return Color(nsColor: .secondaryLabelColor)
        case .claudeCode:  return .indigo
        case .codex:       return .orange
        }
    }
}

// MARK: - ToolStatus

extension ToolStatus {
    var label: String {
        switch self {
        case .active:    return "活跃"
        case .archived:  return "已归档"
        case .broken:    return "已损坏"
        case .unknown:   return "未知"
        }
    }

    var color: Color {
        switch self {
        case .active:    return .green
        case .archived:  return .orange
        case .broken:    return .red
        case .unknown:   return .gray
        }
    }
}

// MARK: - RiskLevel

extension RiskLevel {
    var label: String {
        switch self {
        case .low:    return "低"
        case .medium: return "中"
        case .high:   return "高"
        }
    }

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .yellow
        case .high:   return .red
        }
    }
}
