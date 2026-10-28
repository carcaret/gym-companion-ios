/// Cuando los datos del iPhone no se pueden leer o guardar (2026-10-27): antes no se decía nada y
/// la app salía vacía.
public enum DataErrorText {
    public static let loadTitle = "No se pudieron leer los datos"
    public static let loadMessage = "Tus datos siguen en este iPhone y no se han tocado. Prueba otra vez o, si tienes GitHub configurado, sustitúyelos por los de allí."
    public static let retry = "Reintentar"

    public static let saveTitle = "No se pudo guardar en el iPhone"
    public static let saveMessage = "El último cambio se ve, pero no se ha guardado: si cierras la app, se perderá. Comprueba que el iPhone tiene espacio libre."
    /// Con «Reintentar» (repaso de la HIG, 2026-10-28; antes, solo «Entendido»).
    public static let notNow = "Ahora no"
}
