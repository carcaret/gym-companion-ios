/// Un punto de una gráfica.
public struct ChartPoint: Hashable, Sendable {
    public let date: LocalDate
    public let value: Double
    /// Sesión saltada: repite el último valor real para no romper la línea. (`_skipped`.)
    public let isCarriedForward: Bool

    public init(date: LocalDate, value: Double, isCarriedForward: Bool = false) {
        self.date = date
        self.value = value
        self.isCarriedForward = isCarriedForward
    }
}

/// La serie de un ejercicio.
public struct ExerciseSeries: Hashable, Sendable {
    public let exerciseID: ExerciseID
    public let points: [ChartPoint]
}

/// Datos de la pestaña Gráficas: 1RM estimado y peso de cada ejercicio, solo los que tienen algún
/// punto. Los ejercicios sin peso no tienen 1RM.
public struct ChartSeries: Hashable, Sendable {
    public let e1RM: [ExerciseSeries]
    public let weight: [ExerciseSeries]
}

/// Ejercicios separados entre los que están en alguna rutina y el resto, cada lista por nombre.
public struct RoutineSplit: Hashable, Sendable {
    public let inRoutine: [ExerciseID]
    public let others: [ExerciseID]
}

extension Collection where Element == Session {
    /// Series de 1RM estimado (redondeado a 0,1 kg) y de peso de cada ejercicio entre `from` y `to`.
    /// Una sesión saltada repite el último valor (si aún no lo hay, no pinta nada).
    public func chartSeries(for exercises: [ExerciseID], from: LocalDate, to: LocalDate) -> ChartSeries {
        let sessions = sortedChronologically().filter { $0.date >= from && $0.date <= to }
        var e1RM: [ExerciseSeries] = []
        var weight: [ExerciseSeries] = []
        for exercise in exercises {
            var e1RMPoints: [ChartPoint] = []
            var weightPoints: [ChartPoint] = []
            for session in sessions {
                guard let log = session.log(of: exercise) else { continue }
                if log.skipped {
                    if let last = e1RMPoints.last { e1RMPoints.append(ChartPoint(date: session.date, value: last.value, isCarriedForward: true)) }
                    if let last = weightPoints.last { weightPoints.append(ChartPoint(date: session.date, value: last.value, isCarriedForward: true)) }
                    continue
                }
                if log.estimatedOneRepMax > 0 { e1RMPoints.append(ChartPoint(date: session.date, value: log.roundedEstimatedOneRepMax)) }
                if log.weight > 0 { weightPoints.append(ChartPoint(date: session.date, value: log.weight)) }
            }
            if !e1RMPoints.isEmpty { e1RM.append(ExerciseSeries(exerciseID: exercise, points: e1RMPoints)) }
            if !weightPoints.isEmpty { weight.append(ExerciseSeries(exerciseID: exercise, points: weightPoints)) }
        }
        return ChartSeries(e1RM: e1RM, weight: weight)
    }
}

extension TrainingData {
    /// Ejercicios hechos entre `from` y `to`, sin repetir y por nombre.
    public func exercisesTrained(from: LocalDate, to: LocalDate) -> [ExerciseID] {
        let ids = Set(history.filter { $0.date >= from && $0.date <= to }.flatMap(\.logs).map(\.exerciseID))
        return catalog.sortedByName(ids)
    }
}

extension Catalog {
    /// Separa `exercises` entre los que están en `routineExerciseIDs` y el resto, cada lista por
    /// nombre (el desplegable de Gráficas).
    public func splitByRoutine(_ exercises: [ExerciseID], routineExerciseIDs: some Sequence<ExerciseID>) -> RoutineSplit {
        let inRoutines = Set(routineExerciseIDs)
        return RoutineSplit(inRoutine: sortedByName(exercises.filter(inRoutines.contains)),
                            others: sortedByName(exercises.filter { !inRoutines.contains($0) }))
    }
}
