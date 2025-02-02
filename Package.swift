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
    targets: [
        .target(
            name: "SwiftRepo",
            dependencies: [
                .target(name: "SwiftRepoCore")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "SwiftRepoCore",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "SwiftRepoTest",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .testTarget(
            name: "SwiftRepoTests",
            dependencies: [
                .target(name: "SwiftRepoCore"),
                .target(name: "SwiftRepoTest"),
                .target(name: "SwiftRepo")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
    ]
)
