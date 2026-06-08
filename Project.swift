import ProjectDescription

let project = Project(
    name: "ToolKeeper",
    organizationName: "ToolKeeper",
    targets: [
        .target(
            name: "ToolKeeper",
            destinations: .macOS,
            product: .app,
            bundleId: "com.toolkeeper.app",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "ToolKeeper",
                "CFBundleShortVersionString": "1.1.0",
                "CFBundleVersion": "2",
                "LSMinimumSystemVersion": "14.0",
                "LSApplicationCategoryType": "public.app-category.developer-tools",
                "CFBundleIconFile": "AppIcon",
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true
                ],
            ]),
            sources: ["ToolKeeper/**"],
            resources: ["ToolKeeper/Assets.xcassets/**", "ToolKeeper/AppIcon.icns", "import_tools.json"],
            entitlements: "ToolKeeper/ToolKeeper.entitlements",
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9",
                    "MACOSX_DEPLOYMENT_TARGET": "14.0",
                    "CODE_SIGN_STYLE": "Automatic",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.toolkeeper.app",
                    "MARKETING_VERSION": "1.1.0",
                    "CURRENT_PROJECT_VERSION": "2",
                ]
            )
        ),
        .target(
            name: "ToolKeeperTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.toolkeeper.app.tests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["ToolKeeperTests/**"],
            dependencies: [
                .target(name: "ToolKeeper"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9",
                    "MACOSX_DEPLOYMENT_TARGET": "14.0",
                ]
            )
        ),
    ]
)
