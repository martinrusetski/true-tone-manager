// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrueToneManager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "TrueToneManager",
            path: "Sources/TrueToneManager",
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "CoreBrightness"
                ])
            ]
        ),
        .testTarget(
            name: "UnitTests",
            dependencies: ["TrueToneManager"],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "PropertyTests",
            dependencies: ["TrueToneManager", "SwiftCheck"],
            path: "Tests/PropertyTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["TrueToneManager"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
