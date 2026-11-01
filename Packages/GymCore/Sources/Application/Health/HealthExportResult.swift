import Domain

/// Cómo fue la última vez que se miró Salud.
public enum HealthExportResult: Hashable, Sendable {
    /// Sin GitHub: no hay dónde subirlo (ni se lee Salud).
    case notConfigured
    case unreadable(HealthReadError)
    /// Salud no tiene nada que guardar, o no deja leerlo (sin permiso parece vacío). No se sube:
    /// machacaría lo que hay con nada.
    case empty
    /// Lo de GitHub ya es lo de Salud.
    case upToDate(HealthRecord.Summary)
    case uploaded(HealthRecord.Summary)
    case failed(RemoteError)
}
