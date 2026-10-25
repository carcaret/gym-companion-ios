extension ExerciseLog {
    /// Media de reps por serie. Con reps hechas, una serie vacía cuenta como 0 (como en la PWA);
    /// sin ninguna, el objetivo.
    public var averageReps: Double {
        guard !actualReps.isEmpty else { return Double(targetReps) }
        return Double(actualReps.reduce(0) { $0 + ($1 ?? 0) }) / Double(actualReps.count)
    }

    /// kg · series · reps medias; sin peso, series · reps medias.
    public var volume: Double {
        weight > 0 ? weight * Double(series) * averageReps : Double(series) * averageReps
    }

    /// 1RM estimado (Epley) de la mejor serie: peso · (1 + reps/30). Solo cuentan series de 1 a 30
    /// reps (fuera de ahí la fórmula no es fiable); sin reps hechas, el objetivo. Sin peso, 0.
    public var estimatedOneRepMax: Double {
        guard weight > 0 else { return 0 }
        let reps: [Int?] = actualReps.isEmpty ? [targetReps] : actualReps
        return reps.compactMap { $0 }.filter { (1...30).contains($0) }
            .map { weight * (1 + Double($0) / 30) }.max() ?? 0
    }

    /// Reps que faltaron para el objetivo, sumadas sobre las series rellenadas (las vacías no
    /// cuentan: entreno en curso). Superar el objetivo en una serie no compensa otra.
    public var repShortfall: Int {
        actualReps.compactMap { $0 }.reduce(0) { $0 + Swift.max(0, targetReps - $1) }
    }

    /// Reps realmente hechas, sumando las series rellenadas.
    public var totalReps: Int {
        actualReps.compactMap { $0 }.reduce(0, +)
    }

    /// ¿Bate esta sesión los máximos de volumen y de 1RM estimado de `history`? Hace falta alguna
    /// serie rellenada y superarlos estrictamente.
    public func records(against history: some Collection<Session>) -> Records {
        let previous = history.maxMetrics(for: exerciseID)
        let hasReps = actualReps.contains { $0 != nil }
        return Records(
            isVolumeRecord: hasReps && volume > 0 && volume > previous.volume,
            isE1RMRecord: hasReps && estimatedOneRepMax > 0 && estimatedOneRepMax > previous.estimatedOneRepMax
        )
    }
}

public struct Records: Hashable, Sendable {
    public let isVolumeRecord: Bool
    public let isE1RMRecord: Bool
}

/// Máximos históricos de un ejercicio.
public struct MaxMetrics: Hashable, Sendable {
    public let volume: Double
    public let estimatedOneRepMax: Double
}

extension Collection where Element == Session {
    /// Máximos de volumen y de 1RM estimado de un ejercicio, sin contar las sesiones saltadas.
    public func maxMetrics(for exercise: ExerciseID) -> MaxMetrics {
        let logs = flatMap(\.logs).filter { $0.exerciseID == exercise && !$0.skipped }
        return MaxMetrics(volume: logs.map(\.volume).max() ?? 0,
                          estimatedOneRepMax: logs.map(\.estimatedOneRepMax).max() ?? 0)
    }
}

public enum Metrics {
    /// Variación porcentual redondeada respecto a la sesión anterior; `nil` si no hay anterior
    /// válida o si redondea a 0.
    public static func sessionDeltaPercent(current: Double, previous: Double) -> Int? {
        guard previous > 0 else { return nil }
        let percent = Int(jsRound((current - previous) / previous * 100))
        return percent == 0 ? nil : percent
    }
}
