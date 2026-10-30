// swift-tools-version: 5.9
// Logique d'Écho, sans interface : manches, fantômes, collisions, score, défi du jour, profil, boutique, rythme des pubs.
// Testée avec `swift test` (CI « Écho »). L'app iOS ne fait qu'afficher ce que ce paquet calcule.
import PackageDescription

let package = Package(
    name: "EchoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EchoCore", targets: ["EchoCore"])],
    targets: [
        .target(name: "EchoCore"),
        .testTarget(name: "EchoCoreTests", dependencies: ["EchoCore"]),
    ]
)
