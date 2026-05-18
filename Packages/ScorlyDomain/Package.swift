// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScorlyDomain",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ScorlyDomain", targets: ["ScorlyDomain"]),
    ],
    targets: [
        .target(
            name: "ScorlyDomain",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScorlyDomainTests",
            dependencies: ["ScorlyDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
