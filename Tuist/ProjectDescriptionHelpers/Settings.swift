import ProjectDescription

extension Settings {
    static let appSettings: Settings = .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "COMBINE_HIDPI_IMAGES": "YES",
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": "",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.toolkeeper.app",
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
        ],
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:]),
        ]
    )
}
