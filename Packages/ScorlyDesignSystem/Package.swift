// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyDesignSystem",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyDesignSystem", targets: ["ScorlyDesignSystem"]),
    ],
    targets: [
        .target(
            name: "ScorlyDesignSystem",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyDesignSystemTests",
            dependencies: ["ScorlyDesignSystem"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
