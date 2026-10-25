import Domain
import Testing

// Portados de tests/unit/charts.test.js de la PWA, la parte de datos. Lo que es formato de
// Chart.js (colores, `yAxisID`, `borderDash`, `fill`, `type`) no aplica: en la app lo decide la
// vista con Swift Charts (#11).

private let names = Catalog([
    exercise("press_banca", "Press banca"), exercise("curl_biceps", "Curl bíceps"),
    exercise("sentadilla", "Sentadilla"), exercise("zancadas", "Zancadas"),
])

/// `makeLog` de charts.test.js: sin `actual`, todas las series al objetivo.
private func chartLog(_ id: ExerciseID = "press_banca", weight: Double = 60, series: Int = 3, expected: Int = 10, actual: [Int?]? = nil) -> ExerciseLog {
    makeLog(id, weight: weight, series: series, expected: expected, actual: actual ?? Array(repeating: expected, count: series))
}

private func skippedLog(_ id: ExerciseID = "press_banca") -> ExerciseLog {
    makeLog(id, weight: 0, series: 3, expected: 8, actual: [0, 0, 0], skipped: true)
}

private func entry(_ date: LocalDate, _ logs: ExerciseLog...) -> Session {
    makeSession(date, completed: true, logs: logs)
}

private func data(_ history: [Session]) -> TrainingData {
    TrainingData(catalog: names, history: history)
}

@Suite("getExercisesInRange")
struct ExercisesInRangeTests {
    @Test("devuelve ejercicios únicos dentro del rango de fechas")
    func unique() {
        let result = data([
            entry("2024-03-01", chartLog("press_banca"), chartLog("curl_biceps")),
            entry("2024-03-05", chartLog("press_banca"), chartLog("sentadilla")),
        ]).exercisesTrained(from: "2024-03-01", to: "2024-03-05")
        #expect(Set(result) == ["press_banca", "curl_biceps", "sentadilla"])
        #expect(result.count == 3)
    }

    @Test("excluye entries fuera del rango")
    func outside() {
        let result = data([
            entry("2024-02-28", chartLog("curl_biceps")), entry("2024-03-01", chartLog("press_banca")), entry("2024-03-10", chartLog("sentadilla")),
        ]).exercisesTrained(from: "2024-03-01", to: "2024-03-05")
        #expect(result == ["press_banca"])
    }

    @Test("rango vacío (from > to) → array vacío")
    func emptyRange() {
        #expect(data([entry("2024-03-01", chartLog("press_banca"))]).exercisesTrained(from: "2024-04-01", to: "2024-03-01") == [])
    }

    @Test("ordena por nombre en español (locale es)")
    func spanishOrder() {
        let result = data([entry("2024-03-01", chartLog("zancadas"), chartLog("curl_biceps"), chartLog("press_banca"))])
            .exercisesTrained(from: "2024-03-01", to: "2024-03-31")
        #expect(result == ["curl_biceps", "press_banca", "zancadas"])
    }

    @Test("history vacío devuelve array vacío")
    func empty() { #expect(data([]).exercisesTrained(from: "2024-01-01", to: "2024-12-31") == []) }

    @Test("no duplica ejercicios que aparecen en múltiples entries")
    func noDuplicates() {
        let result = data(["2024-03-01", "2024-03-02", "2024-03-03"].map { entry(LocalDate($0), chartLog("press_banca")) })
            .exercisesTrained(from: "2024-03-01", to: "2024-03-03")
        #expect(result == ["press_banca"])
    }
}

@Suite("buildChartDatasets")
struct ChartDatasetsTests {
    private func series(_ history: [Session], _ ids: [ExerciseID] = ["press_banca"]) -> ChartSeries {
        history.chartSeries(for: ids, from: "2024-03-01", to: "2024-03-31")
    }

    @Test("devuelve e1rmDatasets y weightDatasets (sin datasets de volumen)")
    func shape() {
        // El tipo solo tiene esas dos listas: lo garantiza el compilador.
        let result = series([entry("2024-03-01", chartLog(weight: 60, actual: [10, 10, 10]))])
        #expect(result.e1RM.count == 1)
        #expect(result.weight.count == 1)
    }

    @Test("e1RM usa la mejor serie (max, no promedio)")
    func bestSet() {
        let e1RM = series([entry("2024-03-01", chartLog(weight: 60, actual: [12, 11, 10]))]).e1RM
        #expect(e1RM.count == 1)
        #expect(isClose(e1RM[0].points[0].value, 84, digits: 1))
    }

    @Test("e1RM con series uniformes coincide con la fórmula directa")
    func uniform() {
        let point = series([entry("2024-03-01", chartLog(weight: 60, series: 3, expected: 10, actual: [10, 10, 10]))]).e1RM[0].points[0]
        #expect(point.value == 80)
        #expect(point.date == "2024-03-01")
    }

    @Test("ejercicio bodyweight (weight=0) no genera e1rmDataset")
    func bodyweight() {
        #expect(series([entry("2024-03-01", chartLog(weight: 0, actual: [10, 10, 10]))]).e1RM.isEmpty)
    }

    @Test("genera weightDatasets excluyendo puntos donde weight=0")
    func weightZero() {
        let weight = series([entry("2024-03-01", chartLog(weight: 60)), entry("2024-03-02", chartLog(weight: 0))]).weight
        #expect(weight.count == 1)
        #expect(weight[0].points.map(\.value) == [60])
    }

    @Test("ejercicio sin datos en rango → e1rmDatasets y weightDatasets vacíos")
    func noData() {
        let result = series([entry("2024-01-01", chartLog(weight: 60))])
        #expect(result.e1RM.isEmpty)
        #expect(result.weight.isEmpty)
    }

    @Test("múltiples entries ordenadas por fecha en e1rmDatasets")
    func sorted() {
        let e1RM = series([
            entry("2024-03-05", chartLog(weight: 60, actual: [10, 10, 10])),
            entry("2024-03-01", chartLog(weight: 50, actual: [10, 10, 10])),
            entry("2024-03-03", chartLog(weight: 55, actual: [10, 10, 10])),
        ]).e1RM
        #expect(e1RM[0].points.map(\.date) == ["2024-03-01", "2024-03-03", "2024-03-05"])
    }

    @Test("múltiples ejercicios generan datasets separados con colores distintos")
    func separate() {
        // Los colores los pone la vista; lo que se comprueba es que cada ejercicio va por separado.
        let e1RM = series([entry("2024-03-01", chartLog("press_banca", weight: 60, actual: [10, 10, 10]), chartLog("curl_biceps", weight: 20, actual: [10, 10, 10]))],
                          ["press_banca", "curl_biceps"]).e1RM
        #expect(e1RM.map(\.exerciseID) == ["press_banca", "curl_biceps"])
    }

    @Test("e1RM redondeado a 1 decimal")
    func rounded() {
        #expect(series([entry("2024-03-01", chartLog(weight: 55, actual: [10, 10, 10]))]).e1RM[0].points[0].value == 73.3)
    }

    @Test("reps > 30 excluidas del e1RM (no genera punto)")
    func tooManyReps() {
        #expect(series([entry("2024-03-01", chartLog(weight: 60, actual: [35, 35]))]).e1RM.isEmpty)
    }

    @Test("forward-fill: punto saltado copia el valor previo y se marca _skipped")
    func carryForward() {
        let points = series([
            entry("2024-03-01", chartLog(weight: 80, actual: [8, 8, 8])),
            entry("2024-03-08", skippedLog()),
            entry("2024-03-15", chartLog(weight: 85, actual: [9, 9, 9])),
        ]).weight[0].points
        #expect(points == [
            ChartPoint(date: "2024-03-01", value: 80),
            ChartPoint(date: "2024-03-08", value: 80, isCarriedForward: true),
            ChartPoint(date: "2024-03-15", value: 85),
        ])
    }

    @Test("forward-fill: punto saltado al inicio del rango se omite (sin valor previo)")
    func leadingSkip() {
        let points = series([entry("2024-03-01", skippedLog()), entry("2024-03-08", chartLog(weight: 80, actual: [8, 8, 8]))]).weight[0].points
        #expect(points == [ChartPoint(date: "2024-03-08", value: 80)])
    }

    @Test("forward-fill: e1RM y peso se mantienen de forma independiente")
    func independent() {
        let result = series([entry("2024-03-01", chartLog(weight: 80, actual: [8, 8, 8])), entry("2024-03-08", skippedLog())])
        let previousE1RM = (80 * (1 + 8.0 / 30) * 10).rounded() / 10
        #expect(result.e1RM[0].points[1] == ChartPoint(date: "2024-03-08", value: previousE1RM, isCarriedForward: true))
        #expect(result.weight[0].points[1] == ChartPoint(date: "2024-03-08", value: 80, isCarriedForward: true))
    }
}

@Suite("sortExercisesForDropdown")
struct DropdownTests {
    @Test("separa en inRoutine y others según routineExerciseIds")
    func splits() {
        let split = names.splitByRoutine(["press_banca", "curl_biceps", "sentadilla", "zancadas"], routineExerciseIDs: ["press_banca", "sentadilla"])
        #expect(Set(split.inRoutine) == ["press_banca", "sentadilla"])
        #expect(Set(split.others) == ["curl_biceps", "zancadas"])
    }

    @Test("inRoutine y others están ordenados alfabéticamente en español")
    func sorted() {
        let split = names.splitByRoutine(["zancadas", "curl_biceps", "sentadilla", "press_banca"], routineExerciseIDs: ["zancadas", "press_banca"])
        #expect(split.inRoutine == ["press_banca", "zancadas"])
        #expect(split.others == ["curl_biceps", "sentadilla"])
    }

    @Test("todos en rutina → others vacío")
    func allInRoutine() {
        let split = names.splitByRoutine(["press_banca", "curl_biceps"], routineExerciseIDs: ["press_banca", "curl_biceps"])
        #expect(split.inRoutine == ["curl_biceps", "press_banca"])
        #expect(split.others == [])
    }

    @Test("ninguno en rutina → inRoutine vacío")
    func noneInRoutine() {
        let split = names.splitByRoutine(["press_banca", "curl_biceps"], routineExerciseIDs: [])
        #expect(split.inRoutine == [])
        #expect(split.others == ["curl_biceps", "press_banca"])
    }

    @Test("ejercicios vacíos → ambos grupos vacíos")
    func empty() {
        let split = names.splitByRoutine([], routineExerciseIDs: ["press_banca"])
        #expect(split.inRoutine == [])
        #expect(split.others == [])
    }

    @Test("acepta routineExerciseIds como Set")
    func acceptsSet() {
        let split = names.splitByRoutine(["press_banca", "curl_biceps"], routineExerciseIDs: Set<ExerciseID>(["press_banca"]))
        #expect(split.inRoutine == ["press_banca"])
        #expect(split.others == ["curl_biceps"])
    }

    @Test("IDs en rutina pero sin datos en rango no aparecen en inRoutine")
    func notInInput() {
        let split = names.splitByRoutine(["curl_biceps"], routineExerciseIDs: ["press_banca"])
        #expect(split.inRoutine == [])
        #expect(split.others == ["curl_biceps"])
    }

    @Test("ejercicio en rutina duplicado en routineExerciseIds solo aparece una vez")
    func duplicates() {
        let split = names.splitByRoutine(["press_banca", "curl_biceps"], routineExerciseIDs: ["press_banca", "press_banca"])
        #expect(split.inRoutine == ["press_banca"])
        #expect(split.others == ["curl_biceps"])
    }
}
