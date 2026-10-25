// swift-tools-version: 6.2
// Núcleo de la app, un módulo por capa. Las dependencias entre módulos son las reglas de la
// arquitectura: Domain no depende de nada; Presentation (textos en español para la interfaz) y
// Application, de Domain; ViewModels (estado de cada pantalla, @Observable), de Application,
// Presentation y Domain; Adapters, de Application y Domain. Solo la app conoce los Adapters.
// Nada salvo Adapters importa frameworks de Apple: los tests corren también en Linux.
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
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Presentation", dependencies: ["Domain"]),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "ViewModels", dependencies: ["Application", "Presentation", "Domain"]),
        .target(name: "Adapters", dependencies: ["Application", "Domain"]),
        // Para los tests: dobles de los puertos y tests de contrato que cualquier adaptador de un
        // puerto debe pasar (el local hoy, el de iCloud mañana).
        .target(name: "GymCoreTesting", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain", "GymCoreTesting"]),
        .testTarget(name: "ViewModelsTests", dependencies: ["ViewModels", "Application", "Domain", "GymCoreTesting"]),
        .testTarget(name: "AdaptersTests", dependencies: ["Adapters", "Application", "Domain", "GymCoreTesting"],
                    resources: [.copy("Fixtures")]),
    ]
)
