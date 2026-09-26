// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CultFiveCore",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CultFiveCore", targets: ["CultFiveCore"]),
    ],
    targets: [
        .target(name: "CultFiveCore"),
        .testTarget(name: "CultFiveCoreTests", dependencies: ["CultFiveCore"], resources: [.copy("Fixtures")]),
    ]
)
