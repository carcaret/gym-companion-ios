import Domain

/// Los textos del Historial, los mismos que la PWA (`views/historial.js`).
public enum HistoryText {
    public static let title = "Historial"
    public static let empty = "No hay sesiones registradas"
    public static let incomplete = "Incompleto"
    public static let completeWorkout = "Completar entreno"
    public static let save = "Guardar"

    /// "3 ejercicios · Press Banca · Curl Bíceps · Remo +2" (los tres primeros).
    public static func sessionSummary(_ names: [String]) -> String {
        let preview = names.prefix(3).joined(separator: " · ") + (names.count > 3 ? " +\(names.count - 3)" : "")
        return "\(names.count) ejercicios · \(preview)"
    }

    /// "Full Body - Día 1 — lun, 8 ene 2024".
    public static func detailTitle(routine: String, date: LocalDate) -> String {
        "\(routine) — \(DateText.long(date))"
    }

    public static let deleteTitle = "¿Borrar entreno?"
    public static func deleteMessage(_ date: LocalDate) -> String {
        "Se eliminará el entreno del \(DateText.long(date)). Esta acción no se puede deshacer."
    }
    public static let deleteConfirm = "Borrar"
    public static let cancel = "Cancelar"

    public static let fixBeforeSaving = Notice("Corrige los campos marcados antes de guardar", .warning)
}
