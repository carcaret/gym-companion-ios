import Domain

/// Datos de ejemplo para las capturas del CI (`-demo` al arrancar): el `db-test.json` de la PWA con
/// fechas recientes, para que se vean tiras de historial y récords. Nunca se usan en el iPhone.
enum DemoData {
    static func make(today: LocalDate) -> TrainingData {
        func log(_ id: ExerciseID, _ series: Int, _ target: Int, _ actual: [Int?], _ weight: Double) -> ExerciseLog {
            ExerciseLog(exerciseID: id, series: series, targetReps: target, actualReps: actual, weight: weight)
        }
        return TrainingData(
            catalog: Catalog([
                Exercise(id: "press_banca", name: "Press Banca", group: .pecho),
                Exercise(id: "curl_biceps", name: "Curl Bíceps", group: .biceps),
                Exercise(id: "sentadilla", name: "Sentadilla", group: .piernas),
                Exercise(id: "jalon_al_pecho", name: "Jalón al pecho", group: .espalda),
                Exercise(id: "dominadas", name: "Dominadas", group: .espalda),
            ]),
            routines: [
                Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps", "jalon_al_pecho"]),
                Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sentadilla", "dominadas"]),
                Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["press_banca", "sentadilla"]),
            ],
            history: [
                Session(date: today.adding(days: -21), routineID: "DIA1", completed: true, logs: [
                    log("press_banca", 3, 10, [10, 10, 9], 55), log("curl_biceps", 3, 12, [12, 11, 10], 14), log("jalon_al_pecho", 4, 10, [10, 10, 10, 9], 64),
                ]),
                Session(date: today.adding(days: -14), routineID: "DIA1", completed: true, logs: [
                    log("press_banca", 3, 10, [10, 10, 10], 57.5), log("curl_biceps", 3, 12, [12, 12, 10], 15), log("jalon_al_pecho", 4, 10, [10, 10, 10, 10], 64),
                ]),
                Session(date: today.adding(days: -10), routineID: "DIA2", completed: true, logs: [
                    log("sentadilla", 3, 8, [8, 8, 8], 100), log("dominadas", 4, 10, [10, 10, 9, 8], 0),
                ]),
                Session(date: today.adding(days: -7), routineID: "DIA1", completed: true, logs: [
                    log("press_banca", 3, 10, [10, 10, 8], 60), log("curl_biceps", 3, 12, [12, 12, 12], 15), log("jalon_al_pecho", 4, 11, [11, 10, 10, 10], 68),
                ]),
            ]
        )
    }
}
