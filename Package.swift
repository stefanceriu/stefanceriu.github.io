// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Site",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.58.0")
    ],
    targets: [
        .executableTarget(
            name: "Site",
            dependencies: ["JavaScriptKit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
