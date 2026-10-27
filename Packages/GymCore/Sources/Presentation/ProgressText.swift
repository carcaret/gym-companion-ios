import Domain

/// Frases de la tarjeta Ejercicios de Estadísticas.
public enum ProgressText {
    /// Duración en palabras: días hasta dos semanas, semanas hasta dos meses y luego meses.
    public static func span(days: Int) -> String {
        if days < 14 { return "\(days) días" }
        if days < 60 { return "\(Int((Double(days) / 7).rounded())) semanas" }
        return "\(Int((Double(days) / 30).rounded())) meses"
    }

    /// Lo que ha pasado con el ejercicio. Describe, nunca recomienda: la app no ve descanso,
    /// comida, estrés ni esfuerzo real, que es lo primero que habría que mirar.
    public static func phrase(_ progress: ExerciseProgress) -> String {
        switch progress.status {
        case .noTrack:
            return "\(progress.sessionCount) sesiones, aún sin recorrido"
        case .progressing:
            if let from = progress.weightFrom, let to = progress.weightTo, to > from {
                return "\(LogText.kilograms(from)) → \(LogText.kilograms(to)) kg en \(span(days: progress.spanDays ?? 0))"
            }
            return "\(progress.repsFrom ?? 0) → \(progress.repsTo ?? 0) reps al mismo peso"
        case .stalled:
            if progress.allHit == true {
                return "\(progress.stallSessions) sesiones idénticas, ninguna rep fallada"
            }
            return "\(span(days: progress.spanDays ?? 0)) sin superar \(progress.bestReps) reps"
        }
    }
}

/// Nombres de los grupos musculares, con su ortografía (en los datos van sin tilde).
public enum GroupText {
    private static let spelled: [MuscleGroup: String] = [.biceps: "Bíceps", .triceps: "Tríceps"]

    /// "Bíceps", "Pecho"…; sin grupo, "Sin grupo" (la PWA, "(sin grupo)").
    public static func name(_ group: MuscleGroup?) -> String {
        guard let group else { return "Sin grupo" }
        return spelled[group] ?? group.rawValue.prefix(1).uppercased() + group.rawValue.dropFirst()
    }
}
