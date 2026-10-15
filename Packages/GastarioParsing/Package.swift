// swift-tools-version: 6.2
import PackageDescription

// Parsers puros: solo Foundation, para poder probarlos también en Linux (SPEC §3).
let package = Package(
    name: "GastarioParsing",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GastarioParsing", targets: ["GastarioParsing"]),
    ],
    targets: [
        .target(name: "GastarioParsing"),
        .testTarget(
            name: "GastarioParsingTests",
            dependencies: ["GastarioParsing"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
