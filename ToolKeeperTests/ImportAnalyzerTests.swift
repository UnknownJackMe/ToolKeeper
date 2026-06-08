import XCTest
@testable import ToolKeeper

final class ImportAnalyzerTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportAnalyzerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Git Repo

    func testAnalyzeGitRepo() throws {
        let gitConfigDir = tempDirectory.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitConfigDir, withIntermediateDirectories: true)

        let configContent = "[remote \"origin\"]\n\turl = https://github.com/example/my-tool.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n"
        let configURL = gitConfigDir.appendingPathComponent("config")
        try configContent.write(to: configURL, atomically: true, encoding: .utf8)

        let analysis = ImportAnalyzer.analyzeFolder(at: tempDirectory.path)
        XCTAssertEqual(analysis.gitOriginURL, "https://github.com/example/my-tool.git")
    }

    // MARK: - package.json

    func testAnalyzePackageJson() throws {
        let packageJSON = "{\n  \"scripts\": {\n    \"build\": \"tsc\",\n    \"test\": \"jest\"\n  }\n}\n"
        let packageURL = tempDirectory.appendingPathComponent("package.json")
        try packageJSON.write(to: packageURL, atomically: true, encoding: .utf8)

        let analysis = ImportAnalyzer.analyzeFolder(at: tempDirectory.path)
        XCTAssertTrue(analysis.packageScripts.contains("build"))
        XCTAssertTrue(analysis.packageScripts.contains("test"))
    }

    // MARK: - Cargo.toml

    func testAnalyzeCargoToml() throws {
        let cargoContent = "[package]\nname = \"my-tool\"\nversion = \"0.1.0\"\n"
        let cargoURL = tempDirectory.appendingPathComponent("Cargo.toml")
        try cargoContent.write(to: cargoURL, atomically: true, encoding: .utf8)

        let analysis = ImportAnalyzer.analyzeFolder(at: tempDirectory.path)
        XCTAssertEqual(analysis.cargoPackageName, "my-tool")
    }

    // MARK: - Makefile

    func testAnalyzeMakefile() throws {
        let makefileContent = "build:\n\techo hi\ntest:\n\techo test\n"
        let makefileURL = tempDirectory.appendingPathComponent("Makefile")
        try makefileContent.write(to: makefileURL, atomically: true, encoding: .utf8)

        let analysis = ImportAnalyzer.analyzeFolder(at: tempDirectory.path)
        XCTAssertTrue(analysis.makefileTargets.contains("build"))
        XCTAssertTrue(analysis.makefileTargets.contains("test"))
    }

    // MARK: - Empty Directory

    func testAnalyzeEmptyDir() {
        let analysis = ImportAnalyzer.analyzeFolder(at: tempDirectory.path)

        XCTAssertNil(analysis.gitOriginURL)
        XCTAssertNil(analysis.readmeSummary)
        XCTAssertTrue(analysis.packageScripts.isEmpty)
        XCTAssertTrue(analysis.makefileTargets.isEmpty)
        XCTAssertTrue(analysis.pyprojectScripts.isEmpty)
        XCTAssertNil(analysis.cargoPackageName)
    }
}
