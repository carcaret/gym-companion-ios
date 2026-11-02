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
    /// La unidad de las barras de los grupos, en su cabecera.
    public static let perWeekHeader = "Series por semana"
    public static let setsHeader = "series"
    public static let sessionsHeader = "· sesiones"

    /// Una fila del desglose de un grupo: "6 · 3", series y sesiones.
    public static func setsAndSessions(sets: Int, sessions: Int) -> String { "\(sets) · \(sessions)" }

    public static func window(weeks: Int) -> String { "Últimas \(weeks) semanas" }

    /// "1 de 3 estancados" o, sin ninguno, "Nada estancado · 2 progresando".
    public static func exercisesSubtitle(stalled: Int, total: Int, progressing: Int) -> String {
        stalled > 0 ? "\(stalled) de \(total) \(total == 1 ? "estancado" : "estancados")" : "Nada estancado · \(progressing) progresando"
    }

    /// "10–20 por semana": la franja, en la unidad de las barras.
    public static func referenceBand(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound) por semana"
    }

    /// Las series por semana de un grupo, con un decimal como mucho ("12,8", "11").
    public static func perWeek(_ sets: Double) -> String { oneDecimal(sets) }

    /// El peso de la fila, a la derecha: nada sin peso, ni cuando la frase ya lo dice
    /// («14 → 15 kg en 3 semanas»).
    public static func weight(_ progress: ExerciseProgress) -> String? {
        guard progress.weight > 0, !saysWeight(progress) else { return nil }
        return LogText.weight(progress.weight)
    }

    /// Series indirectas con un decimal como mucho ("2,5", "3").
    public static func indirectSets(_ sets: Double) -> String { oneDecimal(sets) }

    private static func oneDecimal(_ value: Double) -> String {
        LogText.decimal((value * 10).rounded() / 10)
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
            if saysWeight(progress), let from = progress.weightFrom, let to = progress.weightTo {
                return "\(LogText.kilograms(from)) → \(LogText.kilograms(to)) kg en \(span(days: progress.spanDays ?? 0))"
            }
            return "\(progress.repsFrom ?? 0) → \(progress.repsTo ?? 0) reps al mismo peso"
        case .stalled:
            if progress.allHit == true {
                return "\(Plural.sessions(progress.stallSessions)) \(progress.stallSessions == 1 ? "idéntica" : "idénticas"), ninguna rep fallada"
            }
            // En sesiones y no en tiempo: tras un parón, «2 meses sin superar» eran dos sesiones
            // (decisión del usuario, 2026-11-02).
            return "\(Plural.sessions(progress.sessionsWithoutRecord)) sin superar \(progress.bestReps) reps"
        }
    }

    /// Si la frase cuenta una subida de peso.
    private static func saysWeight(_ progress: ExerciseProgress) -> Bool {
        guard progress.status == .progressing, let from = progress.weightFrom, let to = progress.weightTo else { return false }
        return to > from
    }
}
