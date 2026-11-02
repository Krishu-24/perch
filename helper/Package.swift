// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PerchHelper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0"),
    ],
    targets: [
        // Parsing and the shared dev.json model; no AppKit, so it is easy to test.
        .target(name: "PerchDevCore"),
        .executableTarget(
            name: "PerchHelper",
            dependencies: ["PerchDevCore", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .testTarget(name: "PerchDevCoreTests", dependencies: ["PerchDevCore"]),
    ]
)
