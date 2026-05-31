// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureSettings",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureSettings", targets: ["ScorlyFeatureSettings"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyDesignSystem"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureSettings",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "ScorlyDesignSystem", package: "ScorlyDesignSystem"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
