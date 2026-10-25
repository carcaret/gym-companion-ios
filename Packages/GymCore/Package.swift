// swift-tools-version: 6.2
// Núcleo de la app, un módulo por capa. Las dependencias entre módulos son las reglas de la
// arquitectura: Domain no depende de nada; Application, de Domain; Adapters, de los dos.
// Domain y Application no importan frameworks de Apple: sus tests corren también en Linux.
import PackageDescription

let package = Package(
    name: "GymCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Adapters", targets: ["Adapters"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "Adapters", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ]
)
