// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyData",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyData", targets: ["ScorlyData"]),
    ],
    dependencies: [
        .package(path: "../ScorlyDomain"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.43.0"),
    ],
    targets: [
        .target(
            name: "ScorlyData",
            dependencies: [
                .product(name: "ScorlyDomain", package: "ScorlyDomain"),
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyDataTests",
            dependencies: ["ScorlyData"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
