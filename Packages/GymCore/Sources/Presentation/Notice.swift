/// Un aviso breve para el usuario (el `toast` de la PWA).
public struct Notice: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Algo en curso, sin juicio.
        case info
        case success
        /// Guardado (el icono de guardar de la PWA).
        case saved
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
    // Indicador
    public static let pendingChanges = Notice("Hay cambios pendientes de subir a GitHub")
    public static let synced = Notice("Sincronizado con GitHub", .success)
    public static let notConfigured = Notice("GitHub no configurado")

    // Subidas y bajadas automáticas
    public static let autoSaved = Notice("Guardado", .saved)
    public static let savedAfterReconnect = Notice("Guardado en GitHub (recuperado tras reconexión)", .saved)
    public static let remoteApplied = Notice("Datos actualizados desde GitHub", .success)

    // "Subir a GitHub"
    public static let uploading = Notice("Subiendo a GitHub...")
    public static let uploaded = Notice("Subido a GitHub", .success)
    public static let notConfiguredWarning = Notice("GitHub no configurado", .warning)
    public static let uploadFailed = Notice("No se pudo subir — sigue en pendiente", .error)

    // "Descargar de GitHub"
    public static let downloadTitle = "Descargar de GitHub"
    public static let downloadWarning = "Esto sobreescribirá tus datos locales con los de GitHub. Los cambios no subidos se perderán. ¿Continuar?"
    public static let downloadConfirm = "Sobreescribir local"
    public static let downloading = Notice("Descargando de GitHub...")
    public static let downloaded = Notice("Datos descargados de GitHub", .success)
    public static let downloadFailed = Notice("No se pudo descargar o formato inválido", .error)

    // Conflicto
    public static let conflictTitle = "Conflicto con GitHub"
    public static let conflictMessage = "GitHub tiene cambios que no coinciden con los locales (posiblemente editaste db.json a mano). Elige cómo resolver:"
    public static let keepLocalLabel = "Subir local → GitHub"
    public static let keepRemoteLabel = "Bajar GitHub → local"
    public static let cancelLabel = "Cancelar"
    public static let keptLocal = Notice("Datos locales subidos a GitHub", .success)
    public static let cannotConnect = Notice("No se pudo conectar a GitHub", .error)
    public static let keepLocalFailed = Notice("No se pudo subir — sigue en pendiente")
    public static let keptRemote = Notice("Datos de GitHub aplicados localmente", .success)
    public static let keepRemoteFailed = Notice("No se pudo descargar desde GitHub", .error)

    // Al terminar un entreno sin poder subirlo
    public static let savedLocallyTitle = "Entreno guardado localmente"
    public static let savedLocallyMessage = "El entreno se ha guardado en este dispositivo, pero no se pudo subir a GitHub. Se subirá automáticamente cuando haya conexión."
    public static let understood = "Entendido"

    // Configuración (Ajustes)
    public static let repoAndTokenRequired = Notice("Repo y PAT requeridos", .warning)
    public static let configSaved = Notice("Configuración guardada — sincronizando...", .success)
    public static let testing = Notice("Probando conexión...")
    public static let connected = Notice("Conexión exitosa", .success)
    public static let cannotConnectAtAll = Notice("No se pudo conectar", .error)
    public static let invalidRemoteContent = Notice("Conectado, pero el fichero no es un db.json válido", .error)

    public static func connectionError(status: Int) -> Notice {
        Notice("Error \(status) — verifica repo, PAT y rama", .error)
    }
}
