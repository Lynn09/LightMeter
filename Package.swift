// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LightMeter",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LightMeter",
            targets: ["LightMeter"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LightMeter",
            dependencies: [],
            path: "LightMeter",
            exclude: ["Info.plist"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
