import Domain

/// Los textos del Historial, los mismos que la PWA (`views/historial.js`).
public enum HistoryText {
    public static let title = "Historial"
    public static let empty = "No hay sesiones registradas"
    public static let incomplete = "Incompleto"
    public static let completeWorkout = "Completar entreno"
    // Editar una sesión (2026-10-27)
    public static let edit = "Editar"
    public static let discardTitle = "Los cambios en esta sesión se perderán."
    public static let discardConfirm = "Descartar cambios"
    public static let keepEditing = "Seguir editando"
    /// La sesión cambió por otro lado mientras se editaba (el entreno en curso, otra rutina hoy,
    /// lo bajado de GitHub): «OK» no la pisa.
    public static let changedWhileEditing = Notice("La sesión ha cambiado mientras la editabas. Vuelve a editarla.", .warning)

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
    /// La acción de deslizar la fila.
    public static let deleteConfirm = "Borrar"
    /// El botón del globo que lo confirma (repaso de la HIG, 2026-10-28).
    public static let deleteSession = "Borrar entreno"
    public static let cancel = "Cancelar"
}
