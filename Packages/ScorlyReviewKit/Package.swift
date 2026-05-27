// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyReviewKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyReviewKit", targets: ["ScorlyReviewKit"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyDesignSystem"),
    ],
    targets: [
        .target(
            name: "ScorlyReviewKit",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "ScorlyDesignSystem", package: "ScorlyDesignSystem"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyReviewKitTests",
            dependencies: ["ScorlyReviewKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
