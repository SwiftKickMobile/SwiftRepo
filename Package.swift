// swift-tools-version:6.0
import PackageDescription
import CompilerPluginSupport

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
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "510.0.0")
    ],
    targets: [
        .target(
            name: "SwiftRepo",
            dependencies: [
                .target(name: "SwiftRepoCore"),
                .target(name: "SwiftRepoMacros")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "SwiftRepoCore",
            dependencies: [
                .target(name: "SwiftRepoMacros")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
            ]
        ),
        .target(
            name: "SwiftRepoTest",
            dependencies: [
                .target(name: "SwiftRepoCore")
            ],
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
        .macro(
            name: "SwiftRepoMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
    ]
)
