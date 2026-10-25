// swift-tools-version: 6.2
// Núcleo de la app, un módulo por capa. Las dependencias entre módulos son las reglas de la
// arquitectura: Domain no depende de nada; Presentation (textos en español para la interfaz) y
// Application, de Domain; Adapters, de Application y Domain.
// Domain, Presentation y Application no importan frameworks de Apple: sus tests corren también
// en Linux.
import PackageDescription

let package = Package(
    name: "GymCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Adapters", targets: ["Adapters"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Presentation", dependencies: ["Domain"]),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "Adapters", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain"]),
        .testTarget(name: "AdaptersTests", dependencies: ["Adapters", "Application", "Domain"]),
    ]
)
