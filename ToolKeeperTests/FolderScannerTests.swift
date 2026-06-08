import XCTest
@testable import ToolKeeper

final class FolderScannerTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("FolderScannerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    func testScanEmptyDirectory() {
        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertTrue(results.isEmpty)
    }

    func testScanScriptFiles() {
        let fm = FileManager.default
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("run.sh"), contents: Data())
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("main.py"), contents: Data())
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("app.js"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.type == .script })
    }

    func testScanConfigFiles() {
        let fm = FileManager.default
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("package.json"), contents: Data())
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("Makefile"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.type == .config })
    }

    func testScanProjectFiles() {
        let fm = FileManager.default
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("README.md"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .project)
    }

    func testScanSkipsExcludedDirectories() {
        let fm = FileManager.default
        let nodeModules = (tempDir as NSString).appendingPathComponent("node_modules")
        try! fm.createDirectory(atPath: nodeModules, withIntermediateDirectories: true)
        fm.createFile(atPath: (nodeModules as NSString).appendingPathComponent("index.js"), contents: Data())
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("app.py"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "app.py")
    }

    func testScanNestedDirectories() {
        let fm = FileManager.default
        let subDir = (tempDir as NSString).appendingPathComponent("src")
        try! fm.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        fm.createFile(atPath: (subDir as NSString).appendingPathComponent("main.swift"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.path.contains("src/main.swift") == true)
    }

    func testScanIgnoresUnknownExtensions() {
        let fm = FileManager.default
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("data.txt"), contents: Data())
        fm.createFile(atPath: (tempDir as NSString).appendingPathComponent("image.png"), contents: Data())

        let results = FolderScanner.scanFolder(at: tempDir)
        XCTAssertTrue(results.isEmpty)
    }
}
