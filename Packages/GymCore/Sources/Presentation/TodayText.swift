import Domain

/// Los textos de la pantalla Hoy, los mismos que la PWA (`views/hoy.js`).
public enum TodayText {
    // Títulos
    public static let selectorTitle = "Rutinas"
    public static let selectorPrompt = "Selecciona una rutina para entrenar"
    public static func previewTitle(_ routine: String) -> String { "Rutina de \(routine)" }
    public static func activeTitle(_ routine: String) -> String { "Entreno \(routine)" }
    public static func activeStatus(_ routine: String) -> String { "Entreno en curso — \(routine)" }
    public static let completedStatus = "Entreno completado"

    /// "3 ejercicios · Press Banca, Curl Bíceps, Remo..." (los tres primeros).
    public static func routineSummary(_ names: [String]) -> String {
        let preview = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? "..." : "")
        return "\(names.count) ejercicios · \(preview)"
    }

    public static func pendingSwapNote(to: String, from: String) -> String {
        "Próxima vez: \(to) en vez de \(from)"
    }

    // Tarjetas
    public static let weightLabel = "Peso (kg)"
    public static let seriesLabel = "Series"
    public static let targetRepsLabel = "Reps obj."
    public static let seriesSectionLabel = "Reps por serie"
    public static func seriesLabel(_ index: Int) -> String { "S\(index + 1)" }
    public static let emptyRep = "—"
    public static let swapLabel = "Cambiar por otro"
    public static func skipLabel(skipped: Bool) -> String { skipped ? "Reactivar" : "Saltar" }
    public static func removeLabel(oneOff: Bool) -> String { oneOff ? "Quitar" : "Quitar de rutina" }
    public static let volumeRecord = "Volumen"
    public static let e1rmRecord = "e1RM"

    // Botones
    public static let start = "Iniciar entreno"
    public static let finish = "Finalizar entreno"
    public static let addExercise = "Ejercicio"
    /// Cierra el entreno terminado y vuelve al selector.
    public static let done = "Hecho"

    // Selectores de ejercicio
    public static let swapTitle = "Cambiar ejercicio"
    /// Debajo del título: el ejercicio que se va a cambiar.
    public static func swapSubtitle(_ exercise: String) -> String { "En lugar de \(exercise)" }
    /// La sección de los candidatos de otro grupo (la del mismo grupo lleva el nombre del grupo).
    public static let otherGroupsSection = "Otros grupos"
    /// La segunda línea de cada ejercicio del selector: "Pecho · En Día 2, Día 3"; `nil` si no hay
    /// nada que decir.
    public static func pickerDetail(group: String?, routines: [String]) -> String? {
        let parts = [group, routines.isEmpty ? nil : "En " + routines.joined(separator: ", ")].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    public static func addTitle(_ routine: String) -> String { "Añadir a \(routine)" }
    public static let searchPlaceholder = "Buscar ejercicio..."
    public static let oneOffToggle = "Solo esta sesión"
    public static let createExercise = "Crear nuevo ejercicio"
    public static let createTitle = "Crear nuevo ejercicio"
    public static let createNameLabel = "Nombre del ejercicio"
    public static let createNamePlaceholder = "Ej: Press Arnold"
    public static let createConfirm = "Crear y añadir"
    public static let close = "Cerrar"
    public static let cancel = "Cancelar"

    // Quitar
    public static let removeTitle = "¿Quitar ejercicio?"
    public static func removeMessage(exercise: String, routine: String) -> String {
        "Se eliminará \(exercise) de la rutina de \(routine). Los registros históricos se conservarán."
    }
    public static let removeConfirm = "Quitar"

    // Intercambio recíproco
    public static let reciprocalTitle = "Intercambio recíproco"
    public static func reciprocalMessage(new: String, outgoing: String, routine: String) -> String {
        "\(new) pertenece a \(routine). ¿Poner \(outgoing) en su lugar la próxima vez que hagas \(routine) (esta semana)?"
    }
    public static let yes = "Sí"
    public static let no = "No"

    // Avisos
    public static let started = Notice("¡Entreno iniciado!", .success)
    public static let finished = Notice("¡Entreno completado! Guardando...", .success)
    public static let incomplete = Notice("Completa todos los campos antes de finalizar", .warning)
    public static func added(_ exercise: String, oneOff: Bool) -> Notice {
        Notice(oneOff ? "\(exercise) añadido solo para hoy" : "\(exercise) añadido", .success)
    }
    public static func created(_ exercise: String) -> Notice { Notice("\(exercise) creado y añadido", .success) }
    public static let alreadyExists = Notice("Ya existe ese ejercicio", .warning)
    public static let duplicateInWorkout = Notice("Ese ejercicio ya está en el entreno", .warning)
    public static func swapped(to exercise: String) -> Notice { Notice("Cambiado a \(exercise)", .success) }
    public static let noMoreExercises = Notice("No hay más ejercicios disponibles", .warning)
    public static func reciprocalScheduled(_ routine: String) -> Notice { Notice("Se aplicará en \(routine) la próxima vez", .success) }
    public static let reordered = Notice("Orden actualizado")
    public static let removedOneOff = Notice("Ejercicio quitado")
    public static func removed(from routine: String) -> Notice { Notice("Ejercicio eliminado de \(routine)") }
}
