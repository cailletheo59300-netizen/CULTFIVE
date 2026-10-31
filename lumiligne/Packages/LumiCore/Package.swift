// swift-tools-version: 5.9
// Logique de Lumiligne, sans interface : grilles (générateur + solveur), règles, indices, niveaux, grille du jour,
// profil, boutique, rythme des pubs. Testée avec `swift test` (CI « Lumiligne CI »). L'app ne fait qu'afficher.
import PackageDescription

let package = Package(
    name: "LumiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LumiCore", targets: ["LumiCore"])],
    targets: [
        .target(name: "LumiCore"),
        .testTarget(name: "LumiCoreTests", dependencies: ["LumiCore"]),
    ]
)
