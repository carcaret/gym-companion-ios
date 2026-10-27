import Domain

/// Los textos del Historial, los mismos que la PWA (`views/historial.js`).
public enum HistoryText {
    public static let title = "Historial"
    public static let empty = "No hay sesiones registradas"
    public static let incomplete = "Incompleto"
    public static let completeWorkout = "Completar entreno"
    // Editar una sesión (2026-10-27)
    public static let edit = "Editar"
    public static let done = "OK"
    public static let discardTitle = "Los cambios en esta sesión se perderán."
    public static let discardConfirm = "Descartar cambios"
    public static let keepEditing = "Seguir editando"

    /// "3 ejercicios · Press Banca · Curl Bíceps · Remo +2" (los tres primeros).
    public static func sessionSummary(_ names: [String]) -> String {
        let preview = names.prefix(3).joined(separator: " · ") + (names.count > 3 ? " +\(names.count - 3)" : "")
        return "\(names.count) ejercicios · \(preview)"
    }

    /// El detalle de una sesión: la rutina de título y la fecha larga debajo, de subtítulo («lun, 8
    /// ene 2024»); en una sola línea se cortaba (decisión del usuario, 2026-10-27).
    public static func detailSubtitle(_ date: LocalDate) -> String { DateText.long(date) }

    public static let deleteTitle = "¿Borrar entreno?"
    public static func deleteMessage(_ date: LocalDate) -> String {
        "Se eliminará el entreno del \(DateText.long(date)). Esta acción no se puede deshacer."
    }
    public static let deleteConfirm = "Borrar"
    public static let cancel = "Cancelar"
}
