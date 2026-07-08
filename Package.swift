// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrueToneManager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "TrueToneManager",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/TrueToneManager",
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "CoreBrightness",
                    // Locate the embedded Sparkle.framework at runtime once the
                    // executable lives inside the .app bundle we assemble by hand.
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
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
