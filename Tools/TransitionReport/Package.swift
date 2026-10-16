// swift-tools-version: 6.2
import PackageDescription

// Herramienta de la Fase 7: compara el export de Gastario con los CSVs viejos (SPEC, Fase 7).
// Corre en la Mac y en Linux; reutiliza los parsers de la app para leer montos y fechas igual.
let package = Package(
    name: "TransitionReport",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "transition-report", targets: ["transition-report"]),
    ],
    dependencies: [
        .package(path: "../../Packages/GastarioParsing"),
    ],
    targets: [
        .target(name: "TransitionReportKit", dependencies: ["GastarioParsing"]),
        .executableTarget(name: "transition-report", dependencies: ["TransitionReportKit"]),
        .testTarget(name: "TransitionReportKitTests", dependencies: ["TransitionReportKit"]),
    ]
)
