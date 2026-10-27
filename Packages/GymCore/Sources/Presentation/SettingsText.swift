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
    public static let token = "Token (PAT)"
    public static let tokenPlaceholder = "ghp_..."
    public static let save = "Guardar"
    public static let testConnection = "Probar conexión"
    public static let upload = "Subir a GitHub"
    public static let download = "Descargar de GitHub"
    public static let status = "Estado"

    public static func status(_ state: String) -> String { state }
}
