/// Por qué no se puede cambiar un ejercicio de la sesión por otro.
public enum SwapError: Error, Hashable, Sendable {
    /// No hay ejercicio en esa posición.
    case notFound
    /// La sesión ya está terminada.
    case notActive
    /// Es el mismo ejercicio.
    case same
    /// El nuevo ya está en otra posición de la sesión.
    case duplicate
}

extension Session {
    /// Sesión nueva, sin terminar, con un log por ejercicio sembrado con `seed(ejercicio, rutina)`.
    /// (`buildWorkoutEntry` en la PWA.)
    public static func planned(
        date: LocalDate, routine: RoutineID, exerciseIDs: [ExerciseID], seed: (ExerciseID, RoutineID) -> LogSeed
    ) -> Session {
        Session(date: date, routineID: routine, completed: false,
                logs: exerciseIDs.map { ExerciseLog(planning: $0, from: seed($0, routine)) })
    }

    /// Da la sesión por terminada. Las reps no se tocan: ya vienen prerrellenadas al planificar.
    public mutating func finish() {
        completed = true
    }

    /// Cambia el ejercicio de la posición `index` por `newExercise`, sembrado con `seed`. Guarda en
    /// `swappedFrom` el de la rutina original (aunque se cambie varias veces) y lo quita si se
    /// vuelve a él; un ejercicio puntual sigue siéndolo. Si falla, la sesión no cambia.
    @discardableResult
    public mutating func swapExercise(at index: Int, to newExercise: ExerciseID, seed: LogSeed) throws(SwapError) -> ExerciseLog {
        guard logs.indices.contains(index) else { throw .notFound }
        guard !completed else { throw .notActive }
        let current = logs[index]
        guard current.exerciseID != newExercise else { throw .same }
        guard !logs.enumerated().contains(where: { $0.offset != index && $0.element.exerciseID == newExercise }) else {
            throw .duplicate
        }
        let original = current.swappedFrom ?? current.exerciseID
        var log = ExerciseLog(planning: newExercise, from: seed)
        log.swappedFrom = newExercise == original ? nil : original
        log.oneOff = current.oneOff
        logs[index] = log
        return log
    }
}
