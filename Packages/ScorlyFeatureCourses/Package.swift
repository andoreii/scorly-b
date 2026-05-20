// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyFeatureCourses",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyFeatureCourses", targets: ["ScorlyFeatureCourses"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(path: "../ScorlyData"),
        .package(path: "../ScorlyDesignSystem"),
    ],
    targets: [
        .target(
            name: "ScorlyFeatureCourses",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "ScorlyData", package: "ScorlyData"),
                .product(name: "ScorlyDesignSystem", package: "ScorlyDesignSystem"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
