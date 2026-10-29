import Domain

/// Los textos de la pestaña Progreso (`views/estadisticas.js`).
public enum ProgressText {
    /// Como su pestaña (la PWA: «Estadísticas»; decisión del usuario, 2026-10-27).
    public static let title = "Progreso"
    public static let exercisesTitle = "Ejercicios"
    public static let groupsTitle = "Grupos musculares"
    public static let recentSessions = "Últimas sesiones"
    /// Sin nada que comparar (repaso de la HIG, 2026-10-28).
    public static let emptyTitle = "Aún no hay progreso"
    public static let emptyMessage = "Termina un par de entrenos y aquí verás qué avanza y qué se estanca."
    public static let openCharts = "Ver en Gráficas"
    // Las etiquetas sueltas empiezan en mayúscula, como en iOS (repaso de la HIG, 2026-10-28).
    public static let direct = "Directo"
    public static let indirect = "Indirecto"
    public static let setsHeader = "series"
    public static let sessionsHeader = "· sesiones"

    /// Una fila del desglose de un grupo: "6 · 3", series y sesiones.
    public static func setsAndSessions(sets: Int, sessions: Int) -> String { "\(sets) · \(sessions)" }

    /// Las reps de las últimas sesiones, de una en una: "11·11·10  ·  12·11·10".
    public static func recentReps(_ sessions: [String]) -> String { sessions.joined(separator: "  ·  ") }

    public static func window(weeks: Int) -> String { "Últimas \(weeks) semanas" }

    /// "1 de 3 estancados" o, sin ninguno, "Nada estancado · 2 progresando".
    public static func exercisesSubtitle(stalled: Int, total: Int, progressing: Int) -> String {
        stalled > 0 ? "\(stalled) de \(total) \(total == 1 ? "estancado" : "estancados")" : "Nada estancado · \(progressing) progresando"
    }

    public static func referenceBand(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound) series"
    }

    /// Series indirectas con un decimal como mucho ("2,5", "3").
    public static func indirectSets(_ sets: Double) -> String {
        LogText.decimal((sets * 10).rounded() / 10)
    }

    // MARK: - Frases de cada ejercicio

    /// Duración en palabras: días hasta dos semanas, semanas hasta dos meses y luego meses.
    public static func span(days: Int) -> String {
        if days < 14 { return days == 1 ? "1 día" : "\(days) días" }
        if days < 60 { return "\(Int((Double(days) / 7).rounded())) semanas" }
        return "\(Int((Double(days) / 30).rounded())) meses"
    }

    /// Lo que ha pasado con el ejercicio. Describe, nunca recomienda: la app no ve descanso,
    /// comida, estrés ni esfuerzo real, que es lo primero que habría que mirar.
    public static func phrase(_ progress: ExerciseProgress) -> String {
        switch progress.status {
        case .noTrack:
            return "\(Plural.sessions(progress.sessionCount)), aún sin recorrido"
        case .progressing:
            if let from = progress.weightFrom, let to = progress.weightTo, to > from {
                return "\(LogText.kilograms(from)) → \(LogText.kilograms(to)) kg en \(span(days: progress.spanDays ?? 0))"
            }
            return "\(progress.repsFrom ?? 0) → \(progress.repsTo ?? 0) reps al mismo peso"
        case .stalled:
            if progress.allHit == true {
                return "\(Plural.sessions(progress.stallSessions)) \(progress.stallSessions == 1 ? "idéntica" : "idénticas"), ninguna rep fallada"
            }
            return "\(span(days: progress.spanDays ?? 0)) sin superar \(progress.bestReps) reps"
        }
    }
}
