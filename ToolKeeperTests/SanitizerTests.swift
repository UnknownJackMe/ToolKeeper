import XCTest
@testable import ToolKeeper

final class SanitizerTests: XCTestCase {

    // MARK: - GitHub PAT

    func testGitHubPAT() {
        let input = "token ghp_abc123DEF456"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected GitHub PAT to be redacted")
        XCTAssertFalse(result.contains("ghp_abc123DEF456"), "Original PAT should not appear in output")
    }

    func testGitHubPAT2() {
        let input = "github_pat_abc123"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected github_pat_ token to be redacted")
        XCTAssertFalse(result.contains("github_pat_abc123"), "Original token should not appear in output")
    }

    // MARK: - OpenAI Key

    func testOpenAIKey() {
        let input = "sk-abc123def456"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected OpenAI key to be redacted")
        XCTAssertFalse(result.contains("sk-abc123def456"), "Original key should not appear in output")
    }

    // MARK: - AWS Key

    func testAWSKey() {
        let input = "AKIAIOSFODNN7EXAMPLE"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected AWS key to be redacted")
        XCTAssertFalse(result.contains("AKIAIOSFODNN7EXAMPLE"), "Original key should not appear in output")
    }

    // MARK: - Slack Tokens

    func testSlackBotToken() {
        let input = "xoxb-123-456"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected Slack bot token to be redacted")
        XCTAssertFalse(result.contains("xoxb-123-456"), "Original token should not appear in output")
    }

    func testSlackUserToken() {
        let input = "xoxp-123-456"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected Slack user token to be redacted")
        XCTAssertFalse(result.contains("xoxp-123-456"), "Original token should not appear in output")
    }

    // MARK: - Bearer Token

    func testBearerToken() {
        let input = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected Bearer token to be redacted")
        XCTAssertFalse(result.contains("eyJhbGciOiJIUzI1NiJ9"), "Original token should not appear in output")
    }

    // MARK: - Key-Value Patterns

    func testApiKeyPattern() {
        let input = "api_key=secretvalue123"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected api_key value to be redacted")
        XCTAssertFalse(result.contains("secretvalue123"), "Original value should not appear in output")
    }

    func testTokenPattern() {
        let input = "token=mytokenvalue"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected token value to be redacted")
        XCTAssertFalse(result.contains("mytokenvalue"), "Original value should not appear in output")
    }

    func testPasswordPattern() {
        let input = "password=mypassword"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected password value to be redacted")
        XCTAssertFalse(result.contains("mypassword"), "Original password should not appear in output")
    }

    // MARK: - Clean Text

    func testCleanTextUntouched() {
        let input = "echo hello world"
        let result = Sanitizer.sanitize(input)
        XCTAssertEqual(result, input, "Clean text should not be modified")
    }

    // MARK: - Multiple Secrets

    func testMultipleSecrets() {
        let input = "use ghp_xxxToken123 and also sk-yyyKey456 for auth"
        let result = Sanitizer.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"), "Expected secrets to be redacted")
        XCTAssertFalse(result.contains("ghp_xxxToken123"), "GitHub PAT should be redacted")
        XCTAssertFalse(result.contains("sk-yyyKey456"), "OpenAI key should be redacted")
    }
}
