/// Los textos del catálogo de ejercicios (sección catálogo de `views/estadisticas.js`).
public enum CatalogText {
    /// El botón de la barra de Progreso que abre el catálogo, para VoiceOver.
    public static let openLabel = "Catálogo de ejercicios"
    private static func total(_ count: Int) -> String { "\(count) en total" }
    private static func withoutGroup(_ count: Int) -> String { "\(count) sin grupo" }
    /// Debajo del título del catálogo: «4 en total · 1 sin grupo».
    public static func summary(total count: Int, withoutGroup: Int) -> String {
        withoutGroup > 0 ? "\(total(count)) · \(Self.withoutGroup(withoutGroup))" : total(count)
    }

    public static let title = "Ejercicios"
    /// Sin ejercicios en el catálogo (sin coincidencias con lo buscado lo dice la búsqueda de iOS).
    public static let empty = "Aún no hay ejercicios"

    public static let editorTitle = "Editar ejercicio"
    public static let nameLabel = "Nombre"
    public static let groupLabel = "Grupo principal"
    public static let noGroup = "Sin grupo"
    public static let secondaryLabel = "Contribuye también a"
    public static let secondaryHint = "Cada serie cuenta como media serie para estos grupos en la barra de indirecto."

}
