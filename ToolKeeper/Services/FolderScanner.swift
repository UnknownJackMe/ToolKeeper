import Foundation

struct ScanResult {
    let name: String
    let path: String
    let type: ScanResultType
}

enum ScanResultType {
    case script
    case config
    case project
}

enum FolderScanner {

    static let defaultSkipList: [String] = [
        "node_modules", ".git", "Library", "Applications",
        "venv", ".venv", "target", "dist", "build",
        ".cache", ".DS_Store", ".Trash",
    ]

    private static let scriptExtensions: Set<String> = [
        "sh", "command", "py", "js", "ts", "rb", "swift",
    ]

    private static let configFiles: Set<String> = [
        "package.json", "Makefile", "pyproject.toml", "Cargo.toml",
    ]

    static func scanFolder(at path: String, skipping skipList: [String] = defaultSkipList) -> [ScanResult] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return [] }

        var results: [ScanResult] = []
        let skipSet = Set(skipList)

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            let fileName = (relativePath as NSString).lastPathComponent

            // Skip excluded directories
            if skipSet.contains(fileName) {
                enumerator.skipDescendants()
                continue
            }

            let pathExtension = (fileName as NSString).pathExtension
            let type: ScanResultType?

            if scriptExtensions.contains(pathExtension) {
                type = .script
            } else if configFiles.contains(fileName) {
                type = .config
            } else if fileName == "README.md" || fileName == "README" {
                type = .project
            } else {
                type = nil
            }

            if let type {
                results.append(ScanResult(
                    name: relativePath,
                    path: fullPath,
                    type: type
                ))
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
