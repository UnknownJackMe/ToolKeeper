import Foundation
import SwiftUI
import AppKit
import SwiftData

@Observable
final class ImportViewModel {

    // MARK: - Local Folder Import

    var folderPath: String = ""
    var folderAnalysis: FolderAnalysis? = nil

    // MARK: - GitHub Import

    var githubURL: String = ""
    var githubParsed: (owner: String, repo: String)? = nil
    var cloneTargetDir: String = ""

    // MARK: - Folder Scan

    var scanPath: String = ""
    var scanResults: [ScanResult] = []
    var selectedScanResults: Set<String> = []  // keyed by path
    var isScanning: Bool = false

    // MARK: - Local Folder Analysis

    func analyzeLocalFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select a Folder to Import"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        folderPath = url.path
        folderAnalysis = ImportAnalyzer.analyzeFolder(at: url.path)
    }

    // MARK: - GitHub URL Parsing

    func parseGitHubURL() {
        githubParsed = GitParser.parseGitHubOwnerRepo(from: githubURL)
    }

    // MARK: - Import Local Folder

    func importLocalFolder(modelContext: ModelContext) {
        guard let analysis = folderAnalysis else { return }

        let folderName = (folderPath as NSString).lastPathComponent

        // Derive a display name from the git origin or folder name
        var displayName = folderName
        if let originURL = analysis.gitOriginURL,
           let parsed = GitParser.parseGitHubOwnerRepo(from: originURL) {
            displayName = parsed.repo
        }

        // Collect all discovered commands
        var discoveredCommands: [ToolCommand] = []

        // Makefile targets
        for target in analysis.makefileTargets {
            let cmd = ToolCommand(
                toolID: UUID(),
                name: "make \(target)",
                commandText: "make \(target)",
                workingDirectory: folderPath,
                commandDescription: "Makefile target: \(target)"
            )
            discoveredCommands.append(cmd)
        }

        // package.json scripts
        for script in analysis.packageScripts {
            let cmd = ToolCommand(
                toolID: UUID(),
                name: "npm run \(script)",
                commandText: "npm run \(script)",
                workingDirectory: folderPath,
                commandDescription: "npm script: \(script)"
            )
            discoveredCommands.append(cmd)
        }

        // pyproject.toml scripts
        for script in analysis.pyprojectScripts {
            let cmd = ToolCommand(
                toolID: UUID(),
                name: script,
                commandText: script,
                workingDirectory: folderPath,
                commandDescription: "Python script: \(script)"
            )
            discoveredCommands.append(cmd)
        }

        let tool = Tool(
            name: displayName,
            summary: analysis.readmeSummary ?? "",
            sourceType: analysis.detectedSourceType,
            sourceURL: analysis.gitOriginURL,
            localPath: folderPath,
            tags: [],
            status: .active,
            riskLevel: .low,
            notes: ""
        )

        // Set the toolID on each command and link them
        for cmd in discoveredCommands {
            cmd.toolID = tool.id
            cmd.tool = tool
        }
        tool.commands = discoveredCommands

        modelContext.insert(tool)
        try? modelContext.save()

        // Reset state
        folderPath = ""
        folderAnalysis = nil
    }

    // MARK: - Import GitHub Repo

    func importGitHubRepo(modelContext: ModelContext) {
        guard let parsed = githubParsed else { return }

        let tool = Tool(
            name: parsed.repo,
            summary: "",
            sourceType: .github,
            sourceURL: githubURL,
            repoOwner: parsed.owner,
            repoName: parsed.repo,
            tags: [],
            status: .active,
            riskLevel: .low,
            notes: ""
        )

        modelContext.insert(tool)
        try? modelContext.save()

        // Reset state
        githubURL = ""
        githubParsed = nil
    }

    // MARK: - Clone GitHub Repo

    func cloneGitHubRepo() {
        guard let parsed = githubParsed ?? GitParser.parseGitHubOwnerRepo(from: githubURL) else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose Clone Destination"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let targetURL = panel.url else { return }

        cloneTargetDir = targetURL.path
        let cloneURL = "https://github.com/\(parsed.owner)/\(parsed.repo).git"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", cloneURL]
        process.currentDirectoryURL = targetURL

        do {
            try process.run()
        } catch {
            print("[ImportViewModel] git clone failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Folder Scanning

    func scanFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select a Folder to Scan"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        scanPath = url.path
        isScanning = true
        scanResults = []
        selectedScanResults = []

        let path = url.path
        Task.detached { @MainActor [weak self] in
            let results = FolderScanner.scanFolder(at: path)
            self?.scanResults = results
            self?.isScanning = false
        }
    }

    // MARK: - Batch Import from Scan Results

    func importSelectedScanResults(modelContext: ModelContext) {
        let selected = scanResults.filter { selectedScanResults.contains($0.path) }

        for result in selected {
            let name = (result.path as NSString).lastPathComponent
            let parentDir = (result.path as NSString).deletingLastPathComponent

            let tool = Tool(
                name: name,
                summary: "",
                sourceType: .local,
                localPath: result.path,
                defaultWorkingDirectory: parentDir,
                tags: [],
                status: .active,
                riskLevel: .low,
                notes: "Imported from folder scan"
            )

            // Auto-create a run command for scripts
            if result.type == .script {
                let cmd = ToolCommand(
                    toolID: tool.id,
                    name: "Run",
                    commandText: result.path,
                    workingDirectory: parentDir,
                    commandDescription: "Execute \(name)"
                )
                cmd.tool = tool
                tool.commands = [cmd]
            }

            modelContext.insert(tool)
        }

        try? modelContext.save()

        // Reset selection
        selectedScanResults = []
    }
}
