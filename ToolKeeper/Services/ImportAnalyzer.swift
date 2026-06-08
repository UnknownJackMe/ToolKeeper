import Foundation

struct FolderAnalysis {
    var gitOriginURL: String?
    var readmeSummary: String?
    var packageScripts: [String]
    var makefileTargets: [String]
    var pyprojectScripts: [String]
    var cargoPackageName: String?
    var detectedSourceType: SourceType
}

enum ImportAnalyzer {

    static func analyzeFolder(at path: String) -> FolderAnalysis {
        let fm = FileManager.default
        var gitOriginURL: String?
        var readmeSummary: String?
        var packageScripts: [String] = []
        var makefileTargets: [String] = []
        var pyprojectScripts: [String] = []
        var cargoPackageName: String?

        // Git config
        let gitConfigPath = (path as NSString).appendingPathComponent(".git/config")
        if let data = fm.contents(atPath: gitConfigPath),
           let content = String(data: data, encoding: .utf8) {
            gitOriginURL = GitParser.parseOriginURL(from: content)
        }

        // README.md (first 200 lines)
        let readmePath = (path as NSString).appendingPathComponent("README.md")
        if let data = fm.contents(atPath: readmePath),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            let limited = lines.prefix(200).joined(separator: "\n")
            readmeSummary = limited.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // package.json scripts
        let packagePath = (path as NSString).appendingPathComponent("package.json")
        if let data = fm.contents(atPath: packagePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: Any] {
            packageScripts = Array(scripts.keys).sorted()
        }

        // Makefile targets
        let makefilePath = (path as NSString).appendingPathComponent("Makefile")
        if let data = fm.contents(atPath: makefilePath),
           let content = String(data: data, encoding: .utf8) {
            let targetRegex = try? NSRegularExpression(pattern: "^[a-zA-Z_-]+:", options: [])
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                if let match = targetRegex?.firstMatch(in: line, range: range),
                   let matchRange = Range(match.range, in: line) {
                    let target = line[matchRange].dropLast() // remove trailing colon
                    makefileTargets.append(String(target))
                }
            }
        }

        // pyproject.toml scripts section
        let pyprojectPath = (path as NSString).appendingPathComponent("pyproject.toml")
        if let data = fm.contents(atPath: pyprojectPath),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            var inScriptsSection = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "[project.scripts]" {
                    inScriptsSection = true
                    continue
                }
                if trimmed.hasPrefix("[") && inScriptsSection {
                    break
                }
                if inScriptsSection, let eqIndex = trimmed.firstIndex(of: "=") {
                    let key = trimmed[trimmed.startIndex..<eqIndex]
                        .trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        pyprojectScripts.append(key)
                    }
                }
            }
        }

        // Cargo.toml package name
        let cargoPath = (path as NSString).appendingPathComponent("Cargo.toml")
        if let data = fm.contents(atPath: cargoPath),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            var inPackageSection = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "[package]" {
                    inPackageSection = true
                    continue
                }
                if trimmed.hasPrefix("[") && inPackageSection {
                    break
                }
                if inPackageSection, trimmed.hasPrefix("name") {
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        cargoPackageName = parts[1]
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    }
                }
            }
        }

        let sourceType: SourceType = gitOriginURL != nil ? .github : .local

        return FolderAnalysis(
            gitOriginURL: gitOriginURL,
            readmeSummary: readmeSummary,
            packageScripts: packageScripts,
            makefileTargets: makefileTargets,
            pyprojectScripts: pyprojectScripts,
            cargoPackageName: cargoPackageName,
            detectedSourceType: sourceType
        )
    }
}
