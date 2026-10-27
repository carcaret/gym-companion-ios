import Domain

/// Los textos de los ajustes de sincronización (`views/settings.js` e `index.html` de la PWA).
public enum SettingsText {
    public static let title = "Sincronización"
    public static let githubSection = "GitHub"
    public static let repository = "Repositorio"
    public static let repositoryPlaceholder = "usuario/repo"
    public static let branch = "Rama"
    public static let branchPlaceholder = "master"
    public static let path = "Ruta del fichero"
    public static let pathPlaceholder = "db.json"
    /// Rama y ruta casi nunca cambian: van aparte (2026-10-27).
    public static let advancedSection = "Avanzado"
    public static let token = "Token de acceso"
    public static let tokenPlaceholder = "ghp_…"
    public static let save = "Guardar"
    public static let discardTitle = "Los cambios sin guardar se perderán."
    public static let discardConfirm = "Descartar cambios"
    /// Para recuperar los datos de GitHub (la subida es automática; «Subir a GitHub» se quitó el
    /// 2026-10-27).
    public static let download = "Sustituir por los datos de GitHub"
    public static let status = "Estado"

    public static func status(_ state: String) -> String { state }
}
