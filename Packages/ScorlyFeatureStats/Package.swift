// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureStats",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureStats", targets: ["ScorlyFeatureStats"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyData"),
        .package(path: "../ScorlyDesignSystem"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureStats",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "ScorlyData", package: "ScorlyData"),
                .product(name: "ScorlyDesignSystem", package: "ScorlyDesignSystem"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyFeatureStatsTests",
            dependencies: ["ScorlyFeatureStats"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
