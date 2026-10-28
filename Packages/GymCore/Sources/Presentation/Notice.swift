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

    /// Un error no se va solo: espera a que se cierre (repaso de la HIG, 2026-10-28). Lo demás se
    /// va a los pocos segundos.
    public var staysUntilDismissed: Bool { kind == .error }

    /// La acción de VoiceOver que cierra el aviso (con el dedo, se desliza hacia arriba o se toca).
    public static let dismissLabel = "Cerrar aviso"
}

/// Los textos de la sincronización, los mismos que la PWA (`app.js`, `views/settings.js`,
/// `src/store.js`).
public enum SyncText {
    // Indicador y su menú (y el estado en los ajustes). Con «…» lo que abre otra pantalla o pide
    // algo más (repaso de la HIG, 2026-10-28); sincronizar se hace al momento.
    public static let syncNowLabel = "Sincronizar ahora"
    public static let resolveConflictLabel = "Resolver conflicto…"
    public static let configureLabel = "Configurar GitHub…"
    public static let settingsLabel = "Ajustes de sincronización…"
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

    // «Sustituir por los datos de GitHub» (2026-10-27; antes «Descargar de GitHub» con el
    // «¿Continuar?» del `confirm()` de la PWA)
    public static let downloadTitle = "Sustituir por los datos de GitHub"
    public static let downloadWarning = "Los datos de este iPhone se sustituirán por los de GitHub. Lo que no se haya subido se perderá."
    public static let downloadConfirm = "Sustituir"

    // Conflicto: qué datos se quedan, sin flechas ni nombres de fichero (2026-10-27)
    public static let conflictTitle = "Conflicto con GitHub"
    public static let conflictMessage = "GitHub tiene datos distintos de los de este iPhone. ¿Cuáles quieres conservar?"
    public static let keepLocalLabel = "Usar los de este iPhone"
    public static let keepRemoteLabel = "Usar los de GitHub"
    public static let cancelLabel = "Cancelar"

    // "Probar conexión": el resultado va debajo del botón, en el formulario, no en un aviso
    public static let connected = Notice("Conexión exitosa", .success)
    public static let invalidRemoteContent = Notice("Conectado, pero el fichero no es un db.json válido", .error)

    /// Qué pasa y qué revisar, con los nombres de los campos de los ajustes; sin el código ni «PAT»
    /// (repaso de la HIG, 2026-10-28).
    public static func connectionError(status: Int) -> Notice {
        switch status {
        case 401, 403: Notice("GitHub no acepta el token de acceso. Revisa el token, el repositorio y la rama.", .error)
        case 404: Notice("GitHub no encuentra el repositorio, la rama o la ruta. Revísalos.", .error)
        default: Notice("GitHub ha respondido con un error. Prueba otra vez más tarde.", .error)
        }
    }
}
