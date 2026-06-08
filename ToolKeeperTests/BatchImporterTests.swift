import XCTest
import SwiftData
@testable import ToolKeeper

final class BatchImporterTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("BatchImporterTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    @MainActor
    func testImportFromJSON() throws {
        let json = """
        [
          {
            "name": "TestTool",
            "summary": "A test tool",
            "sourceType": "github",
            "sourceURL": "https://github.com/test/test",
            "localPath": null,
            "repoOwner": "test",
            "repoName": "test",
            "tags": ["test", "demo"],
            "status": "active",
            "commands": [
              {
                "name": "Run",
                "commandText": "echo hello",
                "description": "Say hello",
                "requiresConfirmation": false
              }
            ]
          }
        ]
        """

        let jsonPath = (tempDir as NSString).appendingPathComponent("import_tools.json")
        let flagPath = (tempDir as NSString).appendingPathComponent("batch_imported.flag")
        try json.write(toFile: jsonPath, atomically: true, encoding: .utf8)

        let schema = Schema([Tool.self, ToolCommand.self, RunHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        BatchImporter.importIfNeeded(modelContext: container.mainContext, jsonPath: jsonPath, flagPath: flagPath)

        let descriptor = FetchDescriptor<Tool>()
        let tools = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.name, "TestTool")
        XCTAssertEqual(tools.first?.sourceType, .github)
        XCTAssertEqual(tools.first?.tags, ["test", "demo"])
        XCTAssertEqual(tools.first?.commands?.count, 1)
    }

    @MainActor
    func testDuplicatePrevention() throws {
        let json = """
        [{"name": "DupTool", "summary": "", "sourceType": "local", "tags": [], "status": "active", "commands": []}]
        """

        let jsonPath = (tempDir as NSString).appendingPathComponent("import_tools.json")
        let flagPath = (tempDir as NSString).appendingPathComponent("batch_imported.flag")
        try json.write(toFile: jsonPath, atomically: true, encoding: .utf8)

        let schema = Schema([Tool.self, ToolCommand.self, RunHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        // First import
        BatchImporter.importIfNeeded(modelContext: container.mainContext, jsonPath: jsonPath, flagPath: flagPath)

        // Remove flag to allow re-import
        try? FileManager.default.removeItem(atPath: flagPath)

        // Second import
        BatchImporter.importIfNeeded(modelContext: container.mainContext, jsonPath: jsonPath, flagPath: flagPath)

        let descriptor = FetchDescriptor<Tool>(predicate: #Predicate<Tool> { $0.name == "DupTool" })
        let tools = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(tools.count, 1, "Should not create duplicate tools")
    }

    @MainActor
    func testMissingFile() throws {
        let flagPath = (tempDir as NSString).appendingPathComponent("batch_imported.flag")
        let schema = Schema([Tool.self, ToolCommand.self, RunHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        // Should not crash when JSON file doesn't exist
        BatchImporter.importIfNeeded(modelContext: container.mainContext, jsonPath: "/nonexistent/path.json", flagPath: flagPath)

        let descriptor = FetchDescriptor<Tool>()
        let tools = try container.mainContext.fetch(descriptor)
        XCTAssertTrue(tools.isEmpty)
    }

    @MainActor
    func testInvalidJSON() throws {
        let jsonPath = (tempDir as NSString).appendingPathComponent("import_tools.json")
        let flagPath = (tempDir as NSString).appendingPathComponent("batch_imported.flag")
        try "not valid json{{{".write(toFile: jsonPath, atomically: true, encoding: .utf8)

        let schema = Schema([Tool.self, ToolCommand.self, RunHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        // Should not crash on invalid JSON
        BatchImporter.importIfNeeded(modelContext: container.mainContext, jsonPath: jsonPath, flagPath: flagPath)

        // Flag should NOT be set (retry on next launch)
        XCTAssertFalse(FileManager.default.fileExists(atPath: flagPath))
    }
}
