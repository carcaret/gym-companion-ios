/// Un aviso breve para el usuario (el `toast` de la PWA).
public struct Notice: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Algo en curso, sin juicio.
        case info
        case success
        case warning
        case error
    }

    public let text: String
    public let kind: Kind

    public init(_ text: String, _ kind: Kind = .info) {
        self.text = text
        self.kind = kind
    }
}

/// Los textos de la sincronización, los mismos que la PWA (`app.js`, `views/settings.js`,
/// `src/store.js`).
public enum SyncText {
    // Indicador y su menú (y el estado en los ajustes)
    public static let syncNowLabel = "Sincronizar ahora"
    public static let resolveConflictLabel = "Resolver conflicto"
    public static let configureLabel = "Configurar GitHub"
    public static let settingsLabel = "Ajustes de sincronización"
    public static let pendingStatus = "Hay cambios pendientes de subir a GitHub"

    // Avisos (2026-10-27, con la aprobación del usuario: de los de la PWA quedan solo los que
    // dicen algo que no se ve; lo demás lo dicen los botones, el formulario o el indicador)
    public static let waitingForWorkout = Notice("Se subirá a GitHub al terminar el entreno")
    public static let synced = Notice("Sincronizado con GitHub", .success)
    public static let notConfigured = Notice("GitHub no configurado", .warning)
    /// Los datos del iPhone han cambiado: al sincronizar, al descargar o al resolver un conflicto.
    public static let remoteApplied = Notice("Datos actualizados desde GitHub", .success)
    public static let uploaded = Notice("Subido a GitHub", .success)
    public static let offline = Notice("Sin conexión con GitHub", .error)
    public static let uploadFailed = Notice("No se pudo subir a GitHub — sigue pendiente", .error)
    public static let downloadFailed = Notice("No se pudo descargar de GitHub", .error)
    public static let configureFailed = Notice("No se pudo guardar la configuración", .error)

    // "Descargar de GitHub"
    public static let downloadTitle = "Descargar de GitHub"
    public static let downloadWarning = "Esto sobreescribirá tus datos locales con los de GitHub. Los cambios no subidos se perderán. ¿Continuar?"
    public static let downloadConfirm = "Sobreescribir local"

    // Conflicto
    public static let conflictTitle = "Conflicto con GitHub"
    public static let conflictMessage = "GitHub tiene cambios que no coinciden con los locales (posiblemente editaste db.json a mano). Elige cómo resolver:"
    public static let keepLocalLabel = "Subir local → GitHub"
    public static let keepRemoteLabel = "Bajar GitHub → local"
    public static let cancelLabel = "Cancelar"

    // Al terminar un entreno sin poder subirlo
    public static let savedLocallyTitle = "Entreno guardado localmente"
    public static let savedLocallyMessage = "El entreno se ha guardado en este dispositivo, pero no se pudo subir a GitHub. Se subirá automáticamente cuando haya conexión."
    public static let understood = "Entendido"

    // "Probar conexión": el resultado va debajo del botón, en el formulario, no en un aviso
    public static let connected = Notice("Conexión exitosa", .success)
    public static let invalidRemoteContent = Notice("Conectado, pero el fichero no es un db.json válido", .error)

    public static func connectionError(status: Int) -> Notice {
        Notice("Error \(status) — verifica repo, PAT y rama", .error)
    }
}
