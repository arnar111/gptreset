// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CodexResetCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CodexResetCore", targets: ["CodexResetCore"]),
    ],
    targets: [
        .target(
            name: "CodexResetCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "CodexResetCoreTests",
            dependencies: ["CodexResetCore"],
            exclude: ["Fixtures"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
