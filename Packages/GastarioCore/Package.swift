// swift-tools-version: 6.2
import PackageDescription

// Modelos SwiftData y servicios. Solo plataformas Apple: se prueba en el job macos de CI (SPEC §3).
let package = Package(
    name: "GastarioCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GastarioCore", targets: ["GastarioCore"]),
    ],
    dependencies: [
        .package(path: "../GastarioParsing"),
    ],
    targets: [
        .target(
            name: "GastarioCore",
            dependencies: [.product(name: "GastarioParsing", package: "GastarioParsing")]
        ),
        .testTarget(name: "GastarioCoreTests", dependencies: ["GastarioCore"]),
    ]
)
