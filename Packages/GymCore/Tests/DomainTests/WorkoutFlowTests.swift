import Domain
import Testing

// Las reglas del entreno del día sobre todos los datos: empezar, añadir, quitar, reordenar y
// terminar. Antes vivían en TodayModel; sus tests de comportamiento siguen allí.

private let today: LocalDate = "2026-04-24"
private let routine = Routine(id: "DIA1", name: "Día 1", exerciseIDs: ["press_banca", "remo"])

private func data(history: [Session] = [], pending: [RoutineID: PendingSwap] = [:]) -> TrainingData {
    TrainingData(
        catalog: Catalog([exercise("press_banca", "Press Banca", .pecho), exercise("remo", "Remo", .espalda),
                          exercise("curl", "Curl", .biceps)]),
        routines: [routine, Routine(id: "DIA2", name: "Día 2", exerciseIDs: ["curl"])],
        pendingSwaps: pending, history: history
    )
}

private func active(_ logs: [ExerciseLog]) -> Session {
    makeSession(today, routine: "DIA1", logs: logs)
}

@Suite("El entreno del día")
struct WorkoutFlowTests {
    @Test("empezar planifica la rutina con la mejor semilla y sustituye el entreno del día")
    func start() {
        var data = data(history: [makeSession(today, routine: "DIA2", completed: true, logs: [makeLog("curl")])])
        data.startWorkout(routine: "DIA1", on: today)
        let session = data.history.session(on: today)
        #expect(data.history.count == 1)
        #expect(session?.routineID == "DIA1")
        #expect(session?.completed == false)
        #expect(session?.logs.map(\.exerciseID) == ["press_banca", "remo"])
    }

    @Test("empezar aplica el cambio pendiente de la semana; se borra al terminar")
    func startConsumesPending() {
        let pending = PendingSwap(from: "remo", to: "curl", weekStart: today.weekStart)
        var data = data(pending: ["DIA1": pending])
        data.startWorkout(routine: "DIA1", on: today)
        #expect(data.history.session(on: today)?.logs.map(\.exerciseID) == ["press_banca", "curl"])
        #expect(data.pendingSwaps["DIA1"] == pending)
    }

    @Test("añadir un ejercicio lo pone al final del entreno y de la rutina")
    func add() {
        var data = data(history: [active([makeLog("press_banca")])])
        let added = data.addToWorkout("curl", oneOff: false, on: today)
        #expect(added)
        #expect(data.history.session(on: today)?.logs.map(\.exerciseID) == ["press_banca", "curl"])
        #expect(data.routines[0].exerciseIDs == ["press_banca", "remo", "curl"])
    }

    @Test("un ejercicio puntual entra en el entreno, no en la rutina")
    func addOneOff() {
        var data = data(history: [active([makeLog("press_banca")])])
        let added = data.addToWorkout("curl", oneOff: true, on: today)
        #expect(added)
        #expect(data.history.session(on: today)?.logs.last?.oneOff == true)
        #expect(data.routines[0].exerciseIDs == ["press_banca", "remo"])
    }

    @Test("sin entreno en curso no se añade nada")
    func addWithoutWorkout() {
        var data = data(history: [makeSession(today, completed: true)])
        let before = data
        let added = data.addToWorkout("curl", oneOff: false, on: today)
        #expect(!added)
        #expect(data == before)
    }

    @Test("quitar un ejercicio, del entreno o también de la rutina")
    func remove() {
        var data = data(history: [active([makeLog("press_banca"), makeLog("remo")])])
        data.removeFromWorkout("remo", alsoFromRoutine: false, on: today)
        #expect(data.history.session(on: today)?.logs.map(\.exerciseID) == ["press_banca"])
        #expect(data.routines[0].exerciseIDs == ["press_banca", "remo"])
        data.removeFromWorkout("press_banca", alsoFromRoutine: true, on: today)
        #expect(data.history.session(on: today)?.logs.isEmpty == true)
        #expect(data.routines[0].exerciseIDs == ["remo"])
    }

    @Test("reordenar deriva la rutina de los logs: sin los puntuales y con el ejercicio original")
    func reorder() {
        var swapped = makeLog("curl")
        swapped.swappedFrom = "remo"
        var oneOff = makeLog("press_militar")
        oneOff.oneOff = true
        var data = data(history: [active([makeLog("press_banca"), swapped, oneOff])])
        let moved = data.reorderWorkout(from: 1, to: 0, on: today)
        #expect(moved)
        #expect(data.history.session(on: today)?.logs.map(\.exerciseID) == ["curl", "press_banca", "press_militar"])
        #expect(data.routines[0].exerciseIDs == ["remo", "press_banca"])
    }

    @Test("reordenar fuera de rango o a la misma posición no cambia nada")
    func reorderInvalid() {
        var data = data(history: [active([makeLog("press_banca"), makeLog("remo")])])
        let before = data
        let same = data.reorderWorkout(from: 0, to: 0, on: today)
        #expect(!same)
        let outOfRange = data.reorderWorkout(from: 0, to: 5, on: today)
        #expect(!outOfRange)
        #expect(data == before)
    }

    @Test("terminar marca la sesión y borra el cambio pendiente de la rutina")
    func finish() {
        let pending = PendingSwap(from: "remo", to: "curl", weekStart: today.weekStart)
        var data = data(history: [active([makeLog("press_banca", actual: [10, 10, 10])])], pending: ["DIA1": pending])
        data.finishWorkout(on: today)
        #expect(data.history.session(on: today)?.completed == true)
        #expect(data.pendingSwaps["DIA1"] == nil)
    }

    @Test("el nombre de una rutina; si no existe, su id")
    func routineName() {
        let data = data()
        #expect(data.routines.name(of: "DIA1") == "Día 1")
        #expect(data.routines.name(of: "DIA9") == "DIA9")
    }

    @Test("sustituir la sesión de un día")
    func replaceSession() {
        var history = [makeSession(today, logs: [makeLog("press_banca")])]
        history.replace(makeSession(today, logs: [makeLog("remo")]))
        #expect(history.session(on: today)?.logs.map(\.exerciseID) == ["remo"])
        history.replace(makeSession(today.adding(days: 1)))
        #expect(history.count == 1, "Sin sesión ese día, no añade nada")
    }

    @Test("la app sin datos: sin historial ni catálogo")
    func isEmpty() {
        #expect(TrainingData().isEmpty)
        #expect(!data().isEmpty)
        #expect(!TrainingData(history: [makeSession()]).isEmpty)
    }
}

@Suite("Ayudas del dominio")
struct DomainHelpersTests {
    @Test("el log de un ejercicio en una sesión")
    func logOf() {
        let session = makeSession(logs: [makeLog("press_banca"), makeLog("remo", weight: 40)])
        #expect(session.log(of: "remo")?.weight == 40)
        #expect(session.log(of: "curl") == nil)
    }

    @Test("las series vacías valen el objetivo, y las que faltan también")
    func prefilled() {
        let log = makeLog(series: 3, expected: 10, actual: [8, nil])
        #expect(log.repsOrTarget == [8, 10, 10])
        #expect(log.prefilledWithTarget.actualReps == [8, 10, 10])
        #expect(log.prefilledWithTarget.targetReps == 10)
    }

    @Test("las reps de cada serie, tantas como series: las que faltan, vacías; las de más, fuera")
    func seriesReps() {
        #expect(makeLog(series: 3, expected: 10, actual: [8, nil]).seriesReps == [8, nil, nil])
        #expect(makeLog(series: 2, expected: 10, actual: [10, 9, 8]).seriesReps == [10, 9])
    }

    @Test("un paso de los botones −/+: el peso, con el escalón de su carga")
    func step() {
        var light = makeLog(weight: 10)
        light.step(.weight, direction: 1)
        #expect(light.weight == 11)
        var heavy = makeLog(weight: 60)
        heavy.step(.weight, direction: -1)
        #expect(heavy.weight == 55)
        var series = makeLog(series: 3)
        series.step(.series, direction: 1)
        #expect(series.series == 4)
    }

    @Test("validar unos logs se salta los ejercicios saltados")
    func validation() {
        let logs = [makeLog(actual: [10, nil, 10]), makeLog(series: 0, skipped: true)]
        #expect(logs.validation.errorsByLog == [0: [.missingRep(index: 1)]])
        #expect(makeSession(logs: logs).validation == logs.validation)
    }

    @Test("el mismo día n meses antes; si no existe, el siguiente (setMonth de JS)")
    func monthsBefore() {
        #expect(LocalDate("2026-04-24").adding(months: -6) == "2025-10-24")
        #expect(LocalDate("2026-03-31").adding(months: -1) == "2026-03-03")
        #expect(LocalDate("2026-01-15").adding(months: -1) == "2025-12-15")
        #expect(LocalDate("2026-01-15").adding(months: 2) == "2026-03-15")
    }

    @Test("el grupo de un ejercicio, solo si es uno de los que se pueden elegir")
    func knownGroup() {
        #expect(exercise("a", "A", .pecho).knownGroup == .pecho)
        #expect(exercise("a", "A", MuscleGroup("raro")).knownGroup == nil)
        #expect(exercise("a", "A").knownGroup == nil)
    }

    @Test("un nombre ya está en el catálogo si su id ya existe")
    func hasExercise() {
        let catalog = Catalog([exercise("press_banca", "Press Banca")])
        #expect(catalog.hasExercise(named: "Press  banca"))
        #expect(!catalog.hasExercise(named: "Remo"))
    }
}
