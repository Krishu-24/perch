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
        // The desktop widgets' SwiftUI views; no windows, so they can also be rendered to PNGs.
        .target(name: "PerchWidgets", dependencies: ["PerchDevCore"]),
        .executableTarget(
            name: "PerchHelper",
            dependencies: ["PerchDevCore", "PerchWidgets", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        // Renders the widgets with sample data: swift run WidgetSnapshots <folder>
        .executableTarget(name: "WidgetSnapshots", dependencies: ["PerchDevCore", "PerchWidgets"]),
        .testTarget(name: "PerchDevCoreTests", dependencies: ["PerchDevCore"]),
    ]
)
