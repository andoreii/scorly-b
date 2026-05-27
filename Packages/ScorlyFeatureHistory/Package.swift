// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureHistory",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureHistory", targets: ["ScorlyFeatureHistory"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyData"),
        .package(path: "../ScorlyDesignSystem"),
        .package(path: "../ScorlyReviewKit"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureHistory",
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
            name: "ScorlyFeatureHistoryTests",
            dependencies: ["ScorlyFeatureHistory"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
