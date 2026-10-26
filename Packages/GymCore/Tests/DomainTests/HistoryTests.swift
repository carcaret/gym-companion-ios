import Domain
import Testing

// Portados de tests/unit/data.test.js, history.test.js y workout-sync.test.js de la PWA. Los casos
// de `db` nulo o sin `history` no aplican: aquí el historial es una lista, como mucho vacía.

/// Un log de los fixtures de data.test.js.
private func dataLog(_ id: ExerciseID, series: Int, expected: Int, actual: [Int?], weight: Double, skipped: Bool = false) -> ExerciseLog {
    makeLog(id, weight: weight, series: series, expected: expected, actual: actual, skipped: skipped)
}

private func completed(_ date: LocalDate, _ routine: RoutineID = "DIA1", _ logs: ExerciseLog...) -> Session {
    makeSession(date, routine: routine, completed: true, logs: logs)
}

private func open(_ date: LocalDate, _ routine: RoutineID = "DIA1", _ logs: ExerciseLog...) -> Session {
    makeSession(date, routine: routine, completed: false, logs: logs)
}

private let fixture: [Session] = [
    completed("2024-01-08", "DIA1",
              dataLog("press_banca", series: 3, expected: 10, actual: [10, 10, 8], weight: 60),
              dataLog("curl_biceps", series: 3, expected: 12, actual: [12, 12, 10], weight: 15)),
    completed("2024-01-15", "DIA1", dataLog("press_banca", series: 4, expected: 10, actual: [10, 10, 10, 8], weight: 65)),
    completed("2024-01-10", "DIA2", dataLog("sentadilla", series: 3, expected: 8, actual: [8, 8, 8], weight: 100)),
]

@Suite("getTodayEntry")
struct TodayEntryTests {
    @Test("encuentra entry de hoy")
    func finds() { #expect(fixture.session(on: "2024-01-15")?.date == "2024-01-15") }

    @Test("retorna undefined si no hay entry para hoy")
    func missing() { #expect(fixture.session(on: "2024-01-20") == nil) }
}

@Suite("getBestRecentValuesForExercise")
struct BestRecentSeedTests {
    private let today: LocalDate = "2024-05-01"

    private func press(_ date: LocalDate, weight: Double, series: Int = 3, expected: Int = 10, actual: [Int?], completed done: Bool = true, skipped: Bool = false) -> Session {
        makeSession(date, completed: done, logs: [dataLog("press_banca", series: series, expected: expected, actual: actual, weight: weight, skipped: skipped)])
    }

    @Test("mayor peso gana aunque su volumen sea menor")
    func heavierWins() {
        let history = [
            completed("2024-04-08", "DIA1", dataLog("prensa", series: 4, expected: 12, actual: [12, 12, 12, 14], weight: 180)),
            completed("2024-04-22", "DIA1", dataLog("prensa", series: 4, expected: 10, actual: [10, 10, 10, 10], weight: 200)),
        ]
        let best = history.bestRecentSeed(for: "prensa", today: today)
        #expect(best.weight == 200)
        #expect(best.targetReps == 10)
        #expect(best.actualReps == [10, 10, 10, 10])
    }

    @Test("a igualdad de peso, gana mayor volumen (reps reales)")
    func volumeTiebreak() {
        let history = [press("2024-04-01", weight: 50, expected: 12, actual: [12, 12, 12]), press("2024-04-22", weight: 50, actual: [10, 10, 10])]
        let best = history.bestRecentSeed(for: "press_banca", today: today)
        #expect(best.weight == 50)
        #expect(best.actualReps == [12, 12, 12])
    }

    @Test("mezcla mismo peso/series/reps → gana 12-12-12 frente a 12-12-10 frente a 12-10-10")
    func bestReps() {
        let history = [
            press("2024-04-01", weight: 50, expected: 12, actual: [12, 12, 12]),
            press("2024-04-08", weight: 50, expected: 12, actual: [12, 12, 10]),
            press("2024-04-15", weight: 50, expected: 12, actual: [12, 10, 10]),
        ]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).actualReps == [12, 12, 12])
    }

    @Test("busca el ejercicio en cualquier dayType (caso real apertura)")
    func anyRoutine() {
        let history = [
            completed("2024-03-01", "DIA3", dataLog("apertura", series: 4, expected: 12, actual: [12, 12, 12, 12], weight: 15.9)),
            completed("2024-04-01", "DIA2", dataLog("apertura", series: 4, expected: 11, actual: [11, 11, 11, 11], weight: 18.1)),
        ]
        let best = history.bestRecentSeed(for: "apertura", today: today)
        #expect(best.weight == 18.1)
        #expect(best.targetReps == 11)
    }

    @Test("ventana = últimas 6 semanas (las anteriores no compiten aunque tengan más peso)")
    func window() {
        let history = [press("2024-01-01", weight: 200, actual: [10, 10, 10])]
            + ["2024-03-25", "2024-04-01", "2024-04-08", "2024-04-15", "2024-04-22"].map { press(LocalDate($0), weight: 50, actual: [10, 10, 10]) }
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 50)
    }

    @Test("ejercicio dormido (sin sesiones en ventana) → fallback devuelve la MÁS RECIENTE del historial")
    func dormant() {
        let history = [press("2024-01-01", weight: 80, actual: [10, 10, 10]), press("2024-02-08", weight: 50, actual: [10, 10, 10])]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 50)
    }

    @Test("no usa una sesión saltada como semilla (dentro de ventana)")
    func skippedInWindow() {
        let history = [
            press("2024-04-08", weight: 70, expected: 8, actual: [8, 8, 8]),
            press("2024-04-22", weight: 200, expected: 8, actual: [0, 0, 0], skipped: true),
        ]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 70)
    }

    @Test("fallback ignora saltados cuando no hay sesiones en ventana")
    func skippedFallback() {
        let history = [
            press("2024-01-01", weight: 60, expected: 8, actual: [8, 8, 8]),
            press("2024-02-01", weight: 999, expected: 8, actual: [0, 0, 0], skipped: true),
        ]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 60)
    }

    @Test("sin historial → defaults")
    func noHistory() {
        #expect([Session]().bestRecentSeed(for: "press_banca", today: today) == LogSeed(series: 3, targetReps: 10, weight: 0, actualReps: []))
    }

    @Test("ejercicio inexistente en historial → defaults")
    func otherExercise() {
        let history = [completed("2024-04-01", "DIA1", dataLog("otro", series: 3, expected: 10, actual: [10, 10, 10], weight: 50))]
        #expect(history.bestRecentSeed(for: "press_banca", today: today) == .defaults)
    }

    @Test("excluye la entry cuya date === today")
    func excludesToday() {
        let history = [press("2024-04-01", weight: 50, actual: [10, 10, 10]), press(today, weight: 999, actual: [nil, nil, nil], completed: false)]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 50)
    }

    @Test("ignora entries con completed=false dentro de la ventana (coherente con la gráfica)")
    func ignoresOpenInWindow() {
        let history = [press("2024-04-01", weight: 60, actual: [10, 10, 10]), press("2024-04-22", weight: 80, actual: [10, 10, 10], completed: false)]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 60)
    }

    @Test("fallback considera entries con completed=false (única referencia disponible)")
    func fallbackUsesOpen() {
        let history = [press("2024-02-01", weight: 75, actual: [10, 10, 10], completed: false)]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 75)
    }

    @Test("empate total (peso, series, reps) → gana la más reciente")
    func fullTie() {
        let history = [press("2024-04-01", weight: 60, actual: [10, 10, 10]), press("2024-04-15", weight: 60, actual: [10, 10, 10])]
        let best = history.bestRecentSeed(for: "press_banca", today: today)
        #expect(best.weight == 60)
        #expect(best.actualReps == [10, 10, 10])
    }

    @Test("peso 0 (bodyweight) compite por volumen")
    func bodyweight() {
        let history = [
            completed("2024-04-08", "DIA1", dataLog("dominadas", series: 3, expected: 10, actual: [10, 10, 10], weight: 0)),
            completed("2024-04-15", "DIA1", dataLog("dominadas", series: 4, expected: 10, actual: [10, 10, 10, 10], weight: 0)),
        ]
        #expect(history.bestRecentSeed(for: "dominadas", today: today).series == 4)
    }

    @Test("reps.actual con nulls → devuelve el array tal cual")
    func keepsNulls() {
        let history = [press("2024-02-01", weight: 60, actual: [10, nil, nil], completed: false)]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).actualReps == [10, nil, nil])
    }

    @Test("log sin reps.actual → devuelve array vacío")
    func noActual() {
        // En Swift no hay log sin lista de reps: el equivalente es la lista vacía.
        let history = [press("2024-02-01", weight: 50, actual: [])]
        let best = history.bestRecentSeed(for: "press_banca", today: today)
        #expect(best.weight == 50)
        #expect(best.actualReps == [])
    }

    @Test("history desordenado → coge las 6 más recientes por fecha, no por posición")
    func unordered() {
        let history = [
            press("2024-04-22", weight: 50, actual: [10, 10, 10]),
            press("2024-01-01", weight: 100, actual: [10, 10, 10]),
            press("2024-04-08", weight: 50, actual: [10, 10, 10]),
            press("2024-04-15", weight: 50, actual: [10, 10, 10]),
            press("2024-04-01", weight: 50, actual: [10, 10, 10]),
            press("2024-03-25", weight: 50, actual: [10, 10, 10]),
            press("2024-03-18", weight: 50, actual: [10, 10, 10]),
        ]
        #expect(history.bestRecentSeed(for: "press_banca", today: today).weight == 50)
    }

    @Test("today opcional → sin argumento, no excluye ninguna entry")
    func noToday() {
        let history = [press("2024-04-01", weight: 60, actual: [10, 10, 10])]
        #expect(history.bestRecentSeed(for: "press_banca").weight == 60)
    }
}

@Suite("ensureHistorySorted")
struct EnsureHistorySortedTests {
    @Test("ordena history ascendente por fecha")
    func sorts() {
        let history = [completed("2024-03-01"), completed("2024-01-01"), completed("2024-02-01")]
        #expect(history.sortedChronologically().map(\.date) == ["2024-01-01", "2024-02-01", "2024-03-01"])
    }

    @Test("array ya ordenado no cambia")
    func alreadySorted() {
        let history = [completed("2024-01-01"), completed("2024-02-01")]
        #expect(history.sortedChronologically().map(\.date) == ["2024-01-01", "2024-02-01"])
    }

    @Test("array vacío no lanza error")
    func empty() { #expect([Session]().sortedChronologically() == []) }

    @Test("array de un elemento no cambia")
    func single() { #expect([completed("2024-01-01")].sortedChronologically().count == 1) }
}

/// `mkLog` de los tests de getWeeklyBucketsForExercise.
private func weekLog(_ weight: Double, _ series: Int, _ actual: [Int?]) -> ExerciseLog {
    dataLog("press_banca", series: series, expected: 10, actual: actual, weight: weight)
}

@Suite("getWeeklyBucketsForExercise")
struct WeeklyBucketsTests {
    private let anchor: LocalDate = "2026-04-24"

    @Test("devuelve 4 buckets por defecto, ordenados de más antiguo a actual")
    func fourBuckets() {
        let buckets = [Session]().weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(buckets.count == 4)
        #expect(buckets[0].weekStart == "2026-03-30")
        #expect(buckets[0].weekEnd == "2026-04-05")
        #expect(buckets[3].weekStart == "2026-04-20")
        #expect(buckets[3].weekEnd == "2026-04-26")
        #expect(buckets.allSatisfy { $0.session == nil })
    }

    @Test("respeta el parámetro weeks")
    func weeks() {
        let buckets = [Session]().weeklyBuckets(for: "press_banca", anchor: anchor, weeks: 2)
        #expect(buckets.count == 2)
        #expect(buckets[0].weekStart == "2026-04-13")
        #expect(buckets[1].weekStart == "2026-04-20")
    }

    @Test("asigna sesión a su bucket semanal correcto")
    func assigns() {
        let history = [completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10])), completed("2026-04-15", "DIA1", weekLog(55, 3, [10, 10, 10]))]
        let buckets = history.weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(buckets[2].session?.date == "2026-04-15")
        #expect(buckets[3].session?.date == "2026-04-22")
        #expect(buckets[0].session == nil)
        #expect(buckets[1].session == nil)
    }

    @Test("sesiones fuera de la ventana se ignoran")
    func outside() {
        let history = [completed("2025-10-01", "DIA1", weekLog(80, 3, [10, 10, 10])), completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10]))]
        let found = history.weeklyBuckets(for: "press_banca", anchor: anchor).compactMap(\.session)
        #expect(found.map(\.date) == ["2026-04-22"])
    }

    @Test("semanas sin sesión quedan null (hueco visual)")
    func gaps() {
        let history = [completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10])), completed("2026-04-15", "DIA1", weekLog(55, 3, [10, 10, 10]))]
        let buckets = history.weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(buckets.map { $0.session != nil } == [false, false, true, true])
    }

    @Test("entries no completadas se ignoran")
    func ignoresOpen() {
        let history = [open("2026-04-22", "DIA1", weekLog(60, 3, [nil, nil, nil]))]
        #expect(history.weeklyBuckets(for: "press_banca", anchor: anchor)[3].session == nil)
    }

    @Test("excludeDate omite esa fecha aunque caiga en ventana")
    func excludes() {
        let history = [completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10]))]
        #expect(history.weeklyBuckets(for: "press_banca", anchor: anchor, weeks: 4, excluding: "2026-04-22")[3].session == nil)
    }

    @Test("varias sesiones en la misma semana: gana la de mayor volumen")
    func bestVolume() {
        let history = [completed("2026-04-20", "DIA1", weekLog(60, 3, [10, 10, 10])), completed("2026-04-23", "DIA1", weekLog(60, 4, [10, 10, 10, 10]))]
        #expect(history.weeklyBuckets(for: "press_banca", anchor: anchor)[3].session?.date == "2026-04-23")
    }

    @Test("empate de volumen en la misma semana: gana la más reciente")
    func tieNewest() {
        let history = [completed("2026-04-20", "DIA1", weekLog(60, 3, [10, 10, 10])), completed("2026-04-23", "DIA1", weekLog(60, 3, [10, 10, 10]))]
        #expect(history.weeklyBuckets(for: "press_banca", anchor: anchor)[3].session?.date == "2026-04-23")
    }

    @Test("ejercicio sin historial: todos null")
    func otherExercise() {
        let history = [completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10]))]
        #expect(history.weeklyBuckets(for: "otro_ejercicio", anchor: anchor).allSatisfy { $0.session == nil })
    }

    @Test("db null devuelve buckets vacíos bien formados")
    func emptyHistory() {
        // Sin `db` nulo en Swift: con el historial vacío, los buckets salen igual de bien formados.
        let buckets = [Session]().weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(buckets.count == 4)
        #expect(buckets.allSatisfy { $0.session == nil })
        #expect(buckets[3].weekStart == "2026-04-20")
    }

    @Test("no muta db.history")
    func immutable() {
        let history = [completed("2026-04-15", "DIA1", weekLog(55, 3, [10, 10, 10])), completed("2026-04-22", "DIA1", weekLog(60, 3, [10, 10, 10]))]
        _ = history.weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(history.map(\.date) == ["2026-04-15", "2026-04-22"])
    }

    @Test("ancla en lunes funciona igual (W0 empieza ese día)")
    func mondayAnchor() {
        let buckets = [completed("2026-04-20", "DIA1", weekLog(60, 3, [10, 10, 10]))].weeklyBuckets(for: "press_banca", anchor: "2026-04-20")
        #expect(buckets[3].weekStart == "2026-04-20")
        #expect(buckets[3].session?.date == "2026-04-20")
    }

    @Test("sesión el domingo cuenta en su semana (no se desliza a la siguiente)")
    func sunday() {
        let buckets = [completed("2026-04-26", "DIA1", weekLog(60, 3, [10, 10, 10]))].weeklyBuckets(for: "press_banca", anchor: anchor)
        #expect(buckets[3].session?.date == "2026-04-26")
    }
}

@Suite("getRecentSessionsForExercise")
struct RecentSessionsTests {
    private let anchor: LocalDate = "2026-05-01"

    private func entry(_ date: LocalDate, _ weight: Double, _ series: Int, _ actual: [Int?], completed done: Bool = true) -> Session {
        makeSession(date, completed: done, logs: [dataLog("press_banca", series: series, expected: 10, actual: actual, weight: weight)])
    }

    @Test("happy path: devuelve sesiones recientes dentro de la ventana, ordenadas cronológicamente")
    func happyPath() {
        let history = [entry("2026-04-14", 60, 3, [10, 10, 10]), entry("2026-04-21", 65, 3, [10, 10, 10]), entry("2026-04-28", 70, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor).map(\.date) == ["2026-04-14", "2026-04-21", "2026-04-28"])
    }

    @Test("sesiones fuera de la ventana de 6 semanas se excluyen")
    func outside() {
        let history = [entry("2025-10-01", 80, 3, [10, 10, 10]), entry("2026-04-28", 70, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor).map(\.date) == ["2026-04-28"])
    }

    @Test("sesiones posteriores al anchor se excluyen")
    func afterAnchor() {
        let history = [entry("2026-04-28", 70, 3, [10, 10, 10]), entry("2026-05-02", 75, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor).map(\.date) == ["2026-04-28"])
    }

    @Test("maxSessions limita a las N más recientes")
    func maxSessions() {
        let history = ["2026-04-06", "2026-04-13", "2026-04-20", "2026-04-27", "2026-04-28", "2026-04-29", "2026-04-30"]
            .enumerated().map { entry(LocalDate($1), 50 + Double($0) * 5, 3, [10, 10, 10]) }
        let sessions = history.recentSessions(for: "press_banca", anchor: anchor, maxSessions: 6)
        #expect(sessions.count == 6)
        #expect(sessions[0].date == "2026-04-13")
        #expect(sessions[5].date == "2026-04-30")
    }

    @Test("si hay menos sesiones que maxSessions, devuelve todas")
    func fewer() {
        #expect([entry("2026-04-28", 70, 3, [10, 10, 10])].recentSessions(for: "press_banca", anchor: anchor, maxSessions: 6).count == 1)
    }

    @Test("excludeDate excluye esa fecha")
    func excludes() {
        let history = [entry("2026-04-28", 70, 3, [10, 10, 10]), entry(anchor, 75, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor, maxSessions: 6, weeks: 6, excluding: anchor).map(\.date) == ["2026-04-28"])
    }

    @Test("entries no completadas se ignoran")
    func ignoresOpen() {
        #expect([entry("2026-04-28", 70, 3, [nil, nil, nil], completed: false)].recentSessions(for: "press_banca", anchor: anchor).isEmpty)
    }

    @Test("ejercicio no presente en las entries devuelve []")
    func otherExercise() {
        #expect([entry("2026-04-28", 70, 3, [10, 10, 10])].recentSessions(for: "otro_ejercicio", anchor: anchor).isEmpty)
    }

    @Test("history vacía devuelve []")
    func empty() { #expect([Session]().recentSessions(for: "press_banca", anchor: anchor).isEmpty) }

    @Test("no muta db.history")
    func immutable() {
        let history = [entry("2026-04-28", 70, 3, [10, 10, 10]), entry("2026-04-21", 60, 3, [10, 10, 10])]
        _ = history.recentSessions(for: "press_banca", anchor: anchor)
        #expect(history.map(\.date) == ["2026-04-28", "2026-04-21"])
    }

    @Test("historia desordenada → resultado ordenado cronológicamente")
    func unordered() {
        let history = [entry("2026-04-28", 70, 3, [10, 10, 10]), entry("2026-04-14", 55, 3, [10, 10, 10]), entry("2026-04-21", 60, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor).map(\.date) == ["2026-04-14", "2026-04-21", "2026-04-28"])
    }

    @Test("sesión justo en el primer día de la ventana se incluye")
    func firstDay() {
        #expect([entry("2026-03-23", 55, 3, [10, 10, 10])].recentSessions(for: "press_banca", anchor: anchor).map(\.date) == ["2026-03-23"])
    }

    @Test("sesión un día antes del inicio de ventana se excluye")
    func dayBefore() {
        #expect([entry("2026-03-22", 55, 3, [10, 10, 10])].recentSessions(for: "press_banca", anchor: anchor).isEmpty)
    }

    @Test("dos sesiones en la misma semana: ambas aparecen como barras separadas")
    func sameWeek() {
        let history = [entry("2026-04-28", 70, 3, [10, 10, 10]), entry("2026-04-30", 72, 3, [10, 10, 10])]
        #expect(history.recentSessions(for: "press_banca", anchor: anchor, maxSessions: 6, weeks: 6, excluding: anchor).map(\.date) == ["2026-04-28", "2026-04-30"])
    }

    @Test("log correcto asociado a cada sesión")
    func logs() {
        let history = [entry("2026-04-21", 60, 3, [10, 10, 10]), entry("2026-04-28", 70, 4, [12, 12, 12, 12])]
        let sessions = history.recentSessions(for: "press_banca", anchor: anchor)
        #expect(sessions[0].log.weight == 60)
        #expect(sessions[1].log.weight == 70)
        #expect(sessions[1].log.series == 4)
    }
}

// Ejercicios y rutinas de los tests de sortExercisesForSwap:
//   press_banca pecho (DIA1, la activa) · apertura pecho (DIA2) → tier 0 · press_inclinado pecho
//   (sin rutina) → 1 · sentadilla piernas (DIA2) → 2 · plancha core (sin rutina) → 3 ·
//   curl_biceps biceps (DIA1, excluido antes de llamar).
private let swapCatalog = Catalog([
    exercise("press_banca", "Press Banca", .pecho),
    exercise("apertura", "Apertura", .pecho),
    exercise("press_inclinado", "Press Inclinado", .pecho),
    exercise("sentadilla", "Sentadilla", .piernas),
    exercise("plancha", "Plancha", .core),
    exercise("curl_biceps", "Curl Bíceps", .biceps),
])

private func routines(_ days: [RoutineID: [ExerciseID]]) -> [Routine] {
    days.keys.sorted().map { Routine(id: $0, name: $0.rawValue, exerciseIDs: days[$0] ?? []) }
}

private let swapRoutines = routines(["DIA1": ["press_banca", "curl_biceps"], "DIA2": ["sentadilla", "apertura"], "DIA3": []])

private let availableForDIA1Swap = ["apertura", "press_inclinado", "sentadilla", "plancha"].compactMap { swapCatalog[ExerciseID($0)] }

private func sortedIDs(_ available: [Exercise], replacing: ExerciseID, catalog: Catalog = swapCatalog, routines: [Routine] = swapRoutines, routine: RoutineID = "DIA1") -> [ExerciseID] {
    catalog.sortedForSwap(available, replacing: replacing, routines: routines, currentRoutine: routine).map(\.id)
}

@Suite("sortExercisesForSwap — orden de tiers")
struct SwapTierTests {
    @Test("tier 0 primero: mismo grupo (pecho) + en rutina de otro día (DIA2)")
    func tier0() { #expect(sortedIDs(availableForDIA1Swap, replacing: "press_banca")[0] == "apertura") }

    @Test("tier 1 segundo: mismo grupo (pecho) + sin rutina")
    func tier1() { #expect(sortedIDs(availableForDIA1Swap, replacing: "press_banca")[1] == "press_inclinado") }

    @Test("tier 2 tercero: distinto grupo + en rutina de otro día")
    func tier2() { #expect(sortedIDs(availableForDIA1Swap, replacing: "press_banca")[2] == "sentadilla") }

    @Test("tier 3 último: distinto grupo + sin rutina")
    func tier3() { #expect(sortedIDs(availableForDIA1Swap, replacing: "press_banca")[3] == "plancha") }

    @Test("orden completo correcto: [apertura, press_inclinado, sentadilla, plancha]")
    func full() { #expect(sortedIDs(availableForDIA1Swap, replacing: "press_banca") == ["apertura", "press_inclinado", "sentadilla", "plancha"]) }
}

@Suite("sortExercisesForSwap — orden alfabético dentro de cada tier")
struct SwapAlphabeticalTests {
    @Test("tier 0 con varios ejercicios del mismo grupo: orden alfabético entre ellos")
    func tier0() {
        let catalog = Catalog(swapCatalog.all + [exercise("apert_cable", "Apertura con Cable", .pecho), exercise("apert_mancuerna", "Apertura Mancuerna", .pecho)])
        let days = routines(["DIA1": ["press_banca"], "DIA2": ["apert_cable", "apert_mancuerna"]])
        let available = [catalog["apert_mancuerna"]!, catalog["apert_cable"]!]
        #expect(sortedIDs(available, replacing: "press_banca", catalog: catalog, routines: days) == ["apert_cable", "apert_mancuerna"])
    }

    @Test("tier 3 con varios ejercicios sin rutina: orden alfabético entre ellos")
    func tier3() {
        let catalog = Catalog([exercise("zancada", "Zancada", .core), exercise("abs", "Abdominales", .core)])
        let available = [catalog["zancada"]!, catalog["abs"]!]
        #expect(sortedIDs(available, replacing: "press_banca", catalog: catalog, routines: routines(["DIA1": [], "DIA2": []])) == ["abs", "zancada"])
    }
}

@Suite("sortExercisesForSwap — casos de ejercicio origen sin grupo")
struct SwapNoGroupTests {
    @Test("si currentExerciseId no tiene grupo, no se asigna tier 0 ni 1 (solo tier 2/3)")
    func originWithoutGroup() {
        let catalog = Catalog([exercise("sin_grupo", "Sin Grupo"), exercise("apertura", "Apertura", .pecho), exercise("plancha", "Plancha", .core)])
        let days = routines(["DIA1": ["sin_grupo"], "DIA2": ["apertura"]])
        #expect(sortedIDs([catalog["apertura"]!, catalog["plancha"]!], replacing: "sin_grupo", catalog: catalog, routines: days) == ["apertura", "plancha"])
    }

    @Test("si ejercicio disponible no tiene grupo, no sube a tier 0/1 aunque coincida con undefined")
    func candidateWithoutGroup() {
        let catalog = Catalog([exercise("origen", "Origen"), exercise("sin_grupo", "Sin Grupo")])
        let days = routines(["DIA1": ["origen"], "DIA2": []])
        #expect(sortedIDs([catalog["sin_grupo"]!], replacing: "origen", catalog: catalog, routines: days) == ["sin_grupo"])
    }
}

@Suite("sortExercisesForSwap — cambio de dayType activo")
struct SwapOtherRoutineTests {
    @Test("swap desde DIA2: ejercicios de DIA1 van al tier correcto (no al 0 si DIA2 es el activo)")
    func fromDIA2() {
        let catalog = Catalog([exercise("sentadilla", "Sentadilla", .piernas), exercise("press_banca", "Press Banca", .pecho), exercise("prensa", "Prensa", .piernas)])
        let days = routines(["DIA1": ["press_banca"], "DIA2": ["sentadilla"]])
        #expect(sortedIDs([catalog["press_banca"]!, catalog["prensa"]!], replacing: "sentadilla", catalog: catalog, routines: days, routine: "DIA2") == ["prensa", "press_banca"])
    }
}

@Suite("sortExercisesForSwap — inmutabilidad del array de entrada")
struct SwapImmutabilityTests {
    @Test("no muta el array original de ejercicios disponibles")
    func immutable() {
        let available = availableForDIA1Swap
        _ = sortedIDs(available, replacing: "press_banca")
        #expect(available.map(\.id) == ["apertura", "press_inclinado", "sentadilla", "plancha"])
    }
}

// Lo que enseña el selector de "Cambiar por otro": en secciones, con el orden de los tiers dentro.
@Suite("Candidatos para cambiar, por grupo")
struct SwapCandidatesTests {
    private func candidates(replacing exercise: ExerciseID) -> SwapCandidates {
        swapCatalog.swapCandidates(availableForDIA1Swap, replacing: exercise, routines: swapRoutines, currentRoutine: "DIA1")
    }

    @Test("los del mismo grupo aparte, con los de otra rutina primero; el resto en el orden de los tiers")
    func split() {
        let split = candidates(replacing: "press_banca")
        #expect(split.group == .pecho)
        #expect(split.sameGroup.map(\.id) == ["apertura", "press_inclinado"])
        #expect(split.others.map(\.id) == ["sentadilla", "plancha"])
    }

    @Test("sin grupo en el ejercicio que se cambia, todo va al resto")
    func noGroup() {
        let catalog = Catalog(swapCatalog.all + [exercise("misterio", "Misterio")])
        let split = catalog.swapCandidates(availableForDIA1Swap, replacing: "misterio", routines: swapRoutines, currentRoutine: "DIA1")
        #expect(split.group == nil)
        #expect(split.sameGroup.isEmpty)
        #expect(split.others.map(\.id) == ["apertura", "sentadilla", "plancha", "press_inclinado"])
    }
}

@Suite("sortExercisesForSwap — edge cases")
struct SwapEdgeCaseTests {
    @Test("array vacío devuelve array vacío sin errores")
    func empty() { #expect(sortedIDs([], replacing: "press_banca") == []) }

    @Test("un único ejercicio se devuelve tal cual")
    func single() { #expect(sortedIDs([swapCatalog["plancha"]!], replacing: "press_banca") == ["plancha"]) }

    @Test("currentExerciseId no existe en allExercises: no lanza error y degrada a tier 2/3")
    func unknownOrigin() {
        #expect(sortedIDs([swapCatalog["sentadilla"]!, swapCatalog["plancha"]!], replacing: "no_existe") == ["sentadilla", "plancha"])
    }

    @Test("routines con DIA vacío: ejercicios sin rutina siguen en tier 1 o 3 según grupo")
    func emptyDay() {
        let catalog = Catalog([exercise("origen", "Origen", .pecho), exercise("aliado", "Aliado", .pecho)])
        #expect(sortedIDs([catalog["aliado"]!], replacing: "origen", catalog: catalog, routines: routines(["DIA1": ["origen"], "DIA2": []])) == ["aliado"])
    }

    @Test("ejercicio en varias rutinas (incluida otra): va a tier 0 si además comparte grupo")
    func manyRoutines() {
        let catalog = Catalog([exercise("origen", "Origen", .pecho), exercise("multidia", "Multi Día", .pecho), exercise("plancha", "Plancha", .core)])
        let days = routines(["DIA1": ["origen"], "DIA2": ["multidia"], "DIA3": ["multidia"]])
        #expect(sortedIDs([catalog["multidia"]!], replacing: "origen", catalog: catalog, routines: days) == ["multidia"])
        // Con un solo candidato el orden no se ve; con otro de tier 3 delante, sí.
        #expect(sortedIDs([catalog["plancha"]!, catalog["multidia"]!], replacing: "origen", catalog: catalog, routines: days) == ["multidia", "plancha"])
    }
}

@Suite("hasDayOccurredThisWeek")
struct HasDayOccurredThisWeekTests {
    private let history = [
        completed("2026-07-13", "DIA1"),
        completed("2026-07-09", "DIA2"),
        open("2026-07-16", "DIA3"),
    ]
    private let weekStart: LocalDate = "2026-07-13"

    @Test("1 — hay una entrada completada de ese dayType dentro de la semana → true")
    func yes() { #expect(history.hasCompletedSession(of: "DIA1", inWeekStarting: weekStart)) }

    @Test("2 — la entrada de ese dayType es de otra semana → false")
    func otherWeek() { #expect(!history.hasCompletedSession(of: "DIA2", inWeekStarting: weekStart)) }

    @Test("3 — hay entrada esta semana pero no completada → false")
    func notCompleted() { #expect(!history.hasCompletedSession(of: "DIA3", inWeekStarting: weekStart)) }

    @Test("4 — dayType sin ninguna entrada en el historial → false")
    func unknownRoutine() { #expect(!history.hasCompletedSession(of: "DIA_INEXISTENTE", inWeekStarting: weekStart)) }

    @Test("5 — historial vacío/ausente → false")
    func empty() { #expect(![Session]().hasCompletedSession(of: "DIA1", inWeekStarting: weekStart)) }

    @Test("6 — fecha en el último día de la semana (domingo) cuenta como dentro de la semana")
    func sunday() { #expect([completed("2026-07-19", "DIA1")].hasCompletedSession(of: "DIA1", inWeekStarting: weekStart)) }
}

@Suite("sortHistory")
struct SortHistoryTests {
    @Test("ordena por fecha descendente (más reciente primero)")
    func newestFirst() {
        let history = [completed("2026-03-25"), completed("2026-03-28"), completed("2026-03-26")]
        #expect(history.sortedNewestFirst().map(\.date) == ["2026-03-28", "2026-03-26", "2026-03-25"])
    }

    @Test("entries con misma fecha mantienen orden relativo")
    func stable() {
        let history = [completed("2026-03-25", "DIA1"), completed("2026-03-25", "DIA3")]
        let sorted = history.sortedNewestFirst()
        #expect(sorted.count == 2)
        #expect(sorted.map(\.routineID) == ["DIA1", "DIA3"])
    }

    @Test("history vacío devuelve array vacío")
    func empty() { #expect([Session]().sortedNewestFirst() == []) }

    @Test("no muta el array original")
    func immutable() {
        let history = [completed("2026-03-28"), completed("2026-03-25")]
        _ = history.sortedNewestFirst()
        #expect(history.map(\.date) == ["2026-03-28", "2026-03-25"])
    }
}

private let findHistory = [
    completed("2026-03-25", "DIA1", makeLog("press_banca", weight: 50, actual: [10, 10, 10])),
    completed("2026-03-26", "DIA2", makeLog("sentadilla", weight: 80, actual: [8, 8, 8])),
    completed("2026-03-28", "DIA3", makeLog("peso_muerto", weight: 100, actual: [5, 5, 5])),
]

@Suite("findLog")
struct FindLogTests {
    @Test("con fecha existente y logIdx válido devuelve el log")
    func finds() { #expect(findHistory.log(on: "2026-03-25", at: 0)?.exerciseID == "press_banca") }

    @Test("con fecha inexistente devuelve null")
    func missingDate() { #expect(findHistory.log(on: "1999-01-01", at: 0) == nil) }

    @Test("con logIdx fuera de rango devuelve null")
    func outOfRange() { #expect([completed("2026-03-25", "DIA1", makeLog())].log(on: "2026-03-25", at: 99) == nil) }

    @Test("con history vacío devuelve null")
    func empty() { #expect([Session]().log(on: "2026-03-25", at: 0) == nil) }
}

@Suite("isWorkoutActive")
struct IsWorkoutActiveTests {
    private let today: LocalDate = "2026-03-30"

    @Test("entry de hoy con completed=false → true")
    func active() { #expect([open(today)].isWorkoutActive(on: today)) }

    @Test("entry de hoy con completed=true → false")
    func finished() { #expect(![completed(today)].isWorkoutActive(on: today)) }

    @Test("sin entry de hoy → false")
    func noEntry() { #expect(![open("2026-03-29")].isWorkoutActive(on: today)) }

    @Test("historial vacío → false")
    func empty() { #expect(![Session]().isWorkoutActive(on: today)) }

    @Test("entry de otro día completed=false no afecta → false")
    func otherDay() { #expect(![open("2026-03-28"), completed("2026-03-29", "DIA2")].isWorkoutActive(on: today)) }

    @Test("múltiples entries, solo la de hoy importa")
    func onlyToday() { #expect([completed("2026-03-28"), open(today, "DIA2")].isWorkoutActive(on: today)) }
}
