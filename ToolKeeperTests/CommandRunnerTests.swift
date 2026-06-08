import XCTest
@testable import ToolKeeper

@MainActor
final class CommandRunnerTests: XCTestCase {

    func testBasicExecution() async {
        let runner = CommandRunner()
        let expectation = expectation(description: "Command completes")

        runner.run(command: "echo hello", workingDirectory: nil) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertTrue(runner.stdoutLines.contains("hello"))
        XCTAssertEqual(runner.exitCode, 0)
        XCTAssertFalse(runner.isRunning)
    }

    func testErrorOutput() async {
        let runner = CommandRunner()
        let expectation = expectation(description: "Command completes")

        runner.run(command: "echo error >&2", workingDirectory: nil) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertTrue(runner.stderrLines.contains("error"))
    }

    func testNonZeroExitCode() async {
        let runner = CommandRunner()
        let expectation = expectation(description: "Command completes")

        runner.run(command: "exit 42", workingDirectory: nil) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertEqual(runner.exitCode, 42)
    }

    func testTimeout() async {
        let runner = CommandRunner()
        let expectation = expectation(description: "Command completes")

        runner.run(command: "sleep 30", workingDirectory: nil, timeout: 1) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertFalse(runner.isRunning)
        XCTAssertNotEqual(runner.exitCode, 0)
    }

    func testStop() async {
        let runner = CommandRunner()
        let started = expectation(description: "Command started")

        runner.run(command: "sleep 30", workingDirectory: nil, timeout: 0) { _ in
            // No-op
        }

        // Give the process a moment to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            started.fulfill()
        }

        await fulfillment(of: [started], timeout: 2)

        XCTAssertTrue(runner.isRunning)
        runner.stop()

        // Wait a bit for stop to take effect
        let stopped = expectation(description: "Command stopped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stopped.fulfill()
        }
        await fulfillment(of: [stopped], timeout: 2)

        XCTAssertFalse(runner.isRunning)
    }

    func testClear() async {
        let runner = CommandRunner()
        let expectation = expectation(description: "Command completes")

        runner.run(command: "echo test", workingDirectory: nil) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertFalse(runner.stdoutLines.isEmpty)

        runner.clear()

        XCTAssertTrue(runner.stdoutLines.isEmpty)
        XCTAssertTrue(runner.stderrLines.isEmpty)
        XCTAssertNil(runner.exitCode)
    }
}
