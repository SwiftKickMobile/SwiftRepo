// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "SwiftRepo",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
    ],
    products: [
        .library(name: "SwiftRepo", targets: ["SwiftRepo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftKickMobile/SwiftMessages.git", from: "10.0.1"),
    ],
    targets: [
        .target(
            name: "SwiftRepo",
            dependencies: [
                .target(name: "Core")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "Core",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "Test",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .testTarget(
            name: "Tests",
            dependencies: [
                .target(name: "Core"),
                .target(name: "Test"),
                .target(name: "SwiftRepo")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
    ]
)
