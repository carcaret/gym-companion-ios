// swift-tools-version: 6.2
// Núcleo de la app, un módulo por capa. Las dependencias entre módulos son las reglas de la
// arquitectura: Domain no depende de nada; Presentation (textos en español para la interfaz) y
// Application, de Domain; ViewModels (estado de cada pantalla, @Observable), de Application,
// Presentation y Domain; Adapters y AppleAdapters, de Application y Domain; WatchAdapters,
// además, de Adapters. Solo las apps conocen los adaptadores. Nada salvo AppleAdapters y
// WatchAdapters importa frameworks solo de Apple (y lo hacen tras `#if canImport`): los tests
// corren también en Linux.
import PackageDescription

let package = Package(
    name: "GymCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "ViewModels", targets: ["ViewModels"]),
        .library(name: "Adapters", targets: ["Adapters"]),
        .library(name: "AppleAdapters", targets: ["AppleAdapters"]),
        .library(name: "WatchAdapters", targets: ["WatchAdapters"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Presentation", dependencies: ["Domain"]),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "ViewModels", dependencies: ["Application", "Presentation", "Domain"]),
        .target(name: "Adapters", dependencies: ["Application", "Domain"]),
        // Adaptadores que solo existen en Apple (Llavero, UIKit, Network): en Linux compila vacío.
        .target(name: "AppleAdapters", dependencies: ["Application", "Domain"]),
        // El enlace con el reloj (WatchConnectivity), en su módulo: lo usan la app del iPhone y la
        // del reloj, que no tiene UIKit. En Linux compila vacío.
        .target(name: "WatchAdapters", dependencies: ["Adapters", "Application", "Domain"]),
        // Para los tests: dobles de los puertos y tests de contrato que cualquier adaptador de un
        // puerto debe pasar (el local hoy, el de iCloud mañana).
        .target(name: "GymCoreTesting", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain", "GymCoreTesting"]),
        .testTarget(name: "ViewModelsTests", dependencies: ["ViewModels", "Presentation", "Application", "Domain", "GymCoreTesting"]),
        .testTarget(name: "AdaptersTests", dependencies: ["Adapters", "Application", "Domain", "GymCoreTesting"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "AppleAdaptersTests", dependencies: ["AppleAdapters", "Application", "GymCoreTesting"]),
    ]
)
