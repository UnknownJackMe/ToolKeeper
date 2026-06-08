import XCTest
@testable import ToolKeeper

final class GitParserTests: XCTestCase {

    // MARK: - parseOriginURL

    func testParseHTTPSOrigin() {
        let input = "[remote \"origin\"]\n\turl = https://github.com/owner/repo.git\n"
        let result = GitParser.parseOriginURL(from: input)
        XCTAssertEqual(result, "https://github.com/owner/repo.git")
    }

    func testParseSSHOrigin() {
        let input = "[remote \"origin\"]\n\turl = git@github.com:owner/repo.git\n"
        let result = GitParser.parseOriginURL(from: input)
        XCTAssertEqual(result, "git@github.com:owner/repo.git")
    }

    func testParseNoOrigin() {
        let input = "[core]\n\trepositoryformatversion = 0\n"
        let result = GitParser.parseOriginURL(from: input)
        XCTAssertNil(result)
    }

    // MARK: - parseGitHubOwnerRepo

    func testParseGitHubHTTPS() {
        let input = "https://github.com/apple/swift"
        let result = GitParser.parseGitHubOwnerRepo(from: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.owner, "apple")
        XCTAssertEqual(result?.repo, "swift")
    }

    func testParseGitHubHTTPSWithGit() {
        let input = "https://github.com/apple/swift.git"
        let result = GitParser.parseGitHubOwnerRepo(from: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.owner, "apple")
        XCTAssertEqual(result?.repo, "swift")
    }

    func testParseGitHubSSH() {
        let input = "git@github.com:apple/swift.git"
        let result = GitParser.parseGitHubOwnerRepo(from: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.owner, "apple")
        XCTAssertEqual(result?.repo, "swift")
    }

    func testParseNonGitHub() {
        let input = "https://gitlab.com/group/project"
        let result = GitParser.parseGitHubOwnerRepo(from: input)
        XCTAssertNil(result)
    }
}
