// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureAuth",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureAuth", targets: ["ScorlyFeatureAuth"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyData"),
        .package(path: "../ScorlyDesignSystem"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureAuth",
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
            name: "ScorlyFeatureAuthTests",
            dependencies: ["ScorlyFeatureAuth"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
