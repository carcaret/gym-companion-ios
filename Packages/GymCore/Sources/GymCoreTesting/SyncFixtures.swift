import Application
import Domain

/// Los datos de los tests de sincronización: los de los e2e de la PWA (`BASE_DB`). El arnés que los
/// usa es `SyncHarness`.
public enum SyncFixtures {
    public static let today = LocalDate(year: 2026, month: 10, day: 25)!
    public static let location = SyncLocation(repository: "u/r", branch: "main", path: "db.json")
    public static let token = "ghp_testpat"

    public static func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

    public static func pressLog(_ actual: [Int?] = [10, 10, 8], weight: Double = 60) -> ExerciseLog {
        ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: actual, weight: weight)
    }

    /// `BASE_DB` de los e2e de sincronización.
    public static let base = TrainingData(
        catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
        routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"])],
        history: [Session(date: day("2024-01-08"), routineID: "DIA1", completed: true, logs: [pressLog()])]
    )

    public static func adding(_ session: Session, to data: TrainingData = base) -> TrainingData {
        var data = data
        data.history.append(session)
        return data
    }

    public static func adding(_ exercise: Exercise, to data: TrainingData = base) -> TrainingData {
        var data = data
        data.catalog = Catalog(data.catalog.all + [exercise])
        return data
    }

    /// El entreno de hoy en curso (empezado y quizá con algo ajustado).
    public static func activeWorkout(weight: Double = 60, actual: [Int?] = [nil, nil, nil]) -> TrainingData {
        adding(Session(date: today, routineID: "DIA1", completed: false, logs: [pressLog(actual, weight: weight)]))
    }

    /// El entreno de hoy terminado.
    public static func finishedWorkout() -> TrainingData {
        adding(Session(date: today, routineID: "DIA1", completed: true, logs: [pressLog([10, 10, 10])]))
    }
}
