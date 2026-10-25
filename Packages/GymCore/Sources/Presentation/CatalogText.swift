import Domain

/// Los textos del catálogo de ejercicios (sección catálogo de `views/estadisticas.js`).
public enum CatalogText {
    public static let cardTitle = "Catálogo de ejercicios"
    public static let cardSubtitle = "Editar nombres y grupos musculares"
    public static func total(_ count: Int) -> String { "\(count) en total" }
    public static func withoutGroup(_ count: Int) -> String { "\(count) sin grupo" }

    public static let title = "Ejercicios"
    public static let back = "Volver a Estadísticas"
    public static let searchPlaceholder = "Buscar ejercicio..."
    public static let noMatches = "Ningún ejercicio coincide con la búsqueda."

    public static let editorTitle = "Editar ejercicio"
    public static let nameLabel = "Nombre"
    public static let groupLabel = "Grupo principal"
    public static let noGroup = "Sin grupo"
    public static let secondaryLabel = "Contribuye también a"
    public static let secondaryHint = "Cada serie cuenta como media serie para estos grupos en la barra de indirecto."
    public static let cancel = "Cancelar"
    public static let save = "Guardar"

    public static let updated = Notice("Ejercicio actualizado", .success)
}
