import Application
import Domain
import Observation
import Presentation

/// Lo que se sube de Salud (`HealthExport`, #104), visto desde los ajustes: cómo fue la última vez.
@MainActor
@Observable
public final class HealthModel {
    /// `nil` hasta que termina la primera vez.
    public private(set) var result: HealthExportResult?

    private let export: HealthExport

    public init(export: HealthExport) {
        self.export = export
    }

    /// Lee Salud y, si ha cambiado, lo sube (al arrancar y al volver a la app).
    public func refresh() async {
        result = await export.run()
    }

    public var statusText: String {
        switch result {
        case nil: HealthText.checking
        case .notConfigured: HealthText.notConfigured
        case .unreadable(.unavailable): HealthText.unavailable
        case .unreadable(.failed): HealthText.readFailed
        case .empty: HealthText.empty
        case .upToDate(let summary): HealthText.upToDate(summary)
        case .uploaded(let summary): HealthText.uploaded(summary)
        case .failed(.unreachable): HealthText.offline
        case .failed: HealthText.uploadFailed
        }
    }
}
