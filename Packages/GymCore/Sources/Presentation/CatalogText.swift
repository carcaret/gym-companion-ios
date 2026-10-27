import Domain

/// Los textos del catálogo de ejercicios (sección catálogo de `views/estadisticas.js`).
public enum CatalogText {
    public static let cardTitle = "Catálogo de ejercicios"
    public static func total(_ count: Int) -> String { "\(count) en total" }
    public static func withoutGroup(_ count: Int) -> String { "\(count) sin grupo" }

    public static let title = "Ejercicios"
    public static let searchPlaceholder = "Buscar ejercicio…"
    /// Sin ejercicios en el catálogo (sin coincidencias con lo buscado lo dice la búsqueda de iOS).
    public static let empty = "Aún no hay ejercicios"

    public static let editorTitle = "Editar ejercicio"
    public static let nameLabel = "Nombre"
    public static let groupLabel = "Grupo principal"
    public static let noGroup = "Sin grupo"
    public static let secondaryLabel = "Contribuye también a"
    public static let secondaryHint = "Cada serie cuenta como media serie para estos grupos en la barra de indirecto."
    public static let cancel = "Cancelar"
    public static let save = "Guardar"

}
