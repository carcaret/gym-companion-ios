import Domain

/// `tests/fixtures/db-test.json` de la PWA, el que cargan sus e2e (`injectTestSession`), en Swift
/// para los tests de los ViewModels. Un test de `AdaptersTests` comprueba que importar el JSON da
/// exactamente esto.
public enum PWATestDB {
    private static func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

    public static let data = TrainingData(
        catalog: Catalog([
            Exercise(id: "press_banca", name: "Press Banca", group: .pecho),
            Exercise(id: "curl_biceps", name: "Curl Bíceps", group: .biceps),
            Exercise(id: "sentadilla", name: "Sentadilla", group: .piernas),
            Exercise(id: "ejercicio_sin_historial", name: "Ejercicio Sin Historial", group: "otro"),
        ]),
        routines: [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps", "ejercicio_sin_historial"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sentadilla"]),
            Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["press_banca", "sentadilla"]),
        ],
        history: [
            Session(date: day("2024-01-08"), routineID: "DIA1", completed: true, logs: [
                ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 8], weight: 60),
                ExerciseLog(exerciseID: "curl_biceps", series: 3, targetReps: 12, actualReps: [12, 12, 10], weight: 15),
            ]),
            Session(date: day("2024-01-10"), routineID: "DIA2", completed: true, logs: [
                ExerciseLog(exerciseID: "sentadilla", series: 3, targetReps: 8, actualReps: [8, 8, 8], weight: 100),
            ]),
            Session(date: day("2024-01-05"), routineID: "DIA1", completed: true, logs: [
                ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [], weight: 50),
            ]),
        ]
    )
}
