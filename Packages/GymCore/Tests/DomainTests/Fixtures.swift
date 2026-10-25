import Domain

// Equivalentes de los helpers `makeLog`, `makeEntry`, `stubGetLastValues`... de los tests de la PWA.

/// `makeLog` de la PWA: sin `actual`, una serie sin rellenar (`nil`) por cada serie.
func makeLog(
    _ id: ExerciseID = "press_banca", weight: Double = 50, series: Int = 3, expected: Int = 10,
    actual: [Int?]? = nil, skipped: Bool = false
) -> ExerciseLog {
    ExerciseLog(
        exerciseID: id, series: series, targetReps: expected,
        actualReps: actual ?? Array(repeating: nil, count: series), weight: weight, skipped: skipped
    )
}

/// `makeEntry` de la PWA.
func makeSession(
    _ date: LocalDate = "2026-03-28", routine: RoutineID = "DIA1", completed: Bool = false, logs: [ExerciseLog] = []
) -> Session {
    Session(date: date, routineID: routine, completed: completed, logs: logs)
}

/// `stubGetLastValues` de la PWA: los valores de `overrides`, o los de por defecto.
func stubSeeds(_ overrides: [ExerciseID: LogSeed] = [:]) -> (ExerciseID, RoutineID) -> LogSeed {
    { id, _ in overrides[id] ?? .defaults }
}

func seed(series: Int, expected: Int, weight: Double, actual: [Int?] = []) -> LogSeed {
    LogSeed(series: series, targetReps: expected, weight: weight, actualReps: actual)
}

func exercise(_ id: ExerciseID, _ name: String, _ group: MuscleGroup? = nil, secondary: [MuscleGroup]? = nil) -> Exercise {
    Exercise(id: id, name: name, group: group, secondaryGroups: secondary)
}

/// Catálogo indexado por id a partir de una lista.
func catalog(_ exercises: Exercise...) -> [ExerciseID: Exercise] {
    Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
}
