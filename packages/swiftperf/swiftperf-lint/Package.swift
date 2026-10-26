// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swiftperf-lint",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "swiftperf-lint", targets: ["SwiftPerfLint"]),
    ],
    targets: [
        .executableTarget(
            name: "SwiftPerfLint",
            path: "Sources/SwiftPerfLint"
        ),
    ]
)
