import Domain

/// Los textos de la pantalla Hoy, los mismos que la PWA (`views/hoy.js`).
public enum TodayText {
    // Títulos
    public static let selectorTitle = "Rutinas"
    // La vista previa, el entreno en curso y el terminado llevan de título el nombre de la rutina y
    // debajo, de subtítulo, en qué punto está (decisión del usuario, 2026-10-27; la PWA ponía
    // «Rutina de …» y «Entreno …»).
    public static let previewStatus = "Vista previa"
    /// El subtítulo de la barra en el entreno en curso (el `.workout-status` de la PWA).
    public static let inProgress = "En curso"
    public static let completedSubtitle = "Terminado"
    public static let completedStatus = "Entreno completado"

    /// "3 ejercicios · Press Banca, Curl Bíceps, Remo…" (los tres primeros).
    public static func routineSummary(_ names: [String]) -> String {
        let preview = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? "…" : "")
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
    public static let searchPlaceholder = "Buscar ejercicio…"
    public static let oneOffToggle = "Solo esta sesión"
    public static let createExercise = "Crear nuevo ejercicio"
    public static let createTitle = "Crear nuevo ejercicio"
    public static func createNamed(_ name: String) -> String { "Crear «\(name)»" }
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
    // Empezar con el entreno de hoy ya terminado
    public static func replaceTitle(_ done: String) -> String { "Ya has entrenado hoy (\(done))" }
    public static func replaceMessage(_ routine: String) -> String { "Si empiezas \(routine), sustituye al entreno de hoy." }
    public static let replaceConfirm = "Sustituir"
    /// Botones con verbo, no «Sí» y «No» (2026-10-27).
    public static func reciprocalAccept(_ routine: String) -> String { "Cambiar también en \(routine)" }
    public static let reciprocalDecline = "Ahora no"

    /// En el mensaje de la alerta de crear, que se vuelve a abrir con el nombre: un aviso quedaría
    /// debajo de la alerta.
    public static let alreadyExists = "Ya existe ese ejercicio"

    // Avisos
    public static func reciprocalScheduled(_ routine: String) -> Notice { Notice("Se aplicará en \(routine) la próxima vez", .success) }
}
