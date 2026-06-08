import Foundation

enum AppPaths {
    static let appName = "ToolKeeper"

    static var appSupport: String {
        let base = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return (base as NSString).appendingPathComponent(appName)
    }

    static var logs: String {
        (appSupport as NSString).appendingPathComponent("Logs")
    }

    static var settings: String {
        (appSupport as NSString).appendingPathComponent("settings.json")
    }

    static var database: String {
        (appSupport as NSString).appendingPathComponent("ToolKeeper.store")
    }

    static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [appSupport, logs] {
            if !fm.fileExists(atPath: dir) {
                try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
}
