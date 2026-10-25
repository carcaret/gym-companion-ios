import Application

/// Textos de la sincronización (los avisos de la PWA).
public enum SyncText {
    /// Lo que se dice al tocar el indicador (con conflicto, en cambio, se ofrecen las opciones).
    public static func indicator(_ status: SyncStatus) -> String {
        switch status {
        case .disabled: "GitHub no configurado"
        case .ok: "Sincronizado con GitHub"
        case .pending, .conflict: "Hay cambios pendientes de subir a GitHub"
        }
    }

    public static let saved = "Guardado"
    public static let remoteApplied = "Datos actualizados desde GitHub"
    public static let uploaded = "Subido a GitHub"
    public static let notConfigured = "GitHub no configurado"
    public static let uploadFailed = "No se pudo subir — sigue en pendiente"
    public static let keptLocal = "Datos locales subidos a GitHub"
    public static let downloaded = "Datos descargados de GitHub"
    public static let downloadFailed = "No se pudo descargar desde GitHub"
    public static let connectionFailed = "No se pudo conectar a GitHub"
}
