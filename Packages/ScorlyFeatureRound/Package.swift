// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureRound",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureRound", targets: ["ScorlyFeatureRound"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyData"),
        .package(path: "../ScorlyDesignSystem"),
        .package(path: "../ScorlyReviewKit"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureRound",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "ScorlyData", package: "ScorlyData"),
                .product(name: "ScorlyDesignSystem", package: "ScorlyDesignSystem"),
                .product(name: "ScorlyReviewKit", package: "ScorlyReviewKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyFeatureRoundTests",
            dependencies: ["ScorlyFeatureRound"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
