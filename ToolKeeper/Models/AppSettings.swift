import Foundation

@Observable
final class AppSettings: Codable {
    var defaultShell: String
    var defaultToolsDirectory: String
    var logRetentionDays: Int
    var dangerPatterns: [String]
    var anthropicBaseURL: String
    var anthropicAPIKey: String
    var anthropicModel: String
    var anthropicUseFullURL: Bool

    static let defaultDangerPatterns: [String] = [
        "rm -rf",
        "sudo",
        "curl.*\\|.*sh",
        "wget.*\\|.*sh",
        "chmod -R",
        "chown -R",
        "dd ",
        "mkfs",
        "diskutil erase",
        "launchctl unload",
        "launchctl bootout"
    ]

    private static var settingsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("ToolKeeper")
        return directory.appendingPathComponent("settings.json")
    }

    init(
        defaultShell: String = "/bin/zsh",
        defaultToolsDirectory: String = "~/Developer",
        logRetentionDays: Int = 30,
        dangerPatterns: [String] = AppSettings.defaultDangerPatterns,
        anthropicBaseURL: String = "https://api.anthropic.com",
        anthropicAPIKey: String = "",
        anthropicModel: String = "claude-sonnet-4-20250514",
        anthropicUseFullURL: Bool = false
    ) {
        self.defaultShell = defaultShell
        self.defaultToolsDirectory = defaultToolsDirectory
        self.logRetentionDays = logRetentionDays
        self.dangerPatterns = dangerPatterns
        self.anthropicBaseURL = anthropicBaseURL
        self.anthropicAPIKey = anthropicAPIKey
        self.anthropicModel = anthropicModel
        self.anthropicUseFullURL = anthropicUseFullURL
    }

    // MARK: - Persistence

    static func load() -> AppSettings {
        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppSettings()
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    func save() {
        let url = Self.settingsFileURL
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[AppSettings] Failed to save settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Path Helpers

    var expandedDefaultToolsDirectory: String {
        (defaultToolsDirectory as NSString).expandingTildeInPath
    }

    static func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
