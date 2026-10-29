import Domain
import Testing

// Reglas que antes calculaban los modelos de pantalla o Presentation (repaso del 2026-10-29). Su
// comportamiento lo siguen probando los tests portados de la PWA; estos fijan la regla en Domain.

private let today: LocalDate = "2026-04-24"

private func data(logs: [ExerciseLog], routine: [ExerciseID] = ["press_banca"],
                  otherRoutine: [ExerciseID] = ["remo"], history: [Session] = []) -> TrainingData {
    TrainingData(
        catalog: Catalog([exercise("press_banca", "Press Banca", .pecho), exercise("remo", "Remo", .espalda),
                          exercise("curl", "Curl", .biceps), exercise("aperturas", "Aperturas", .pecho)]),
        routines: [Routine(id: "DIA1", name: "Día 1", exerciseIDs: routine),
                   Routine(id: "DIA2", name: "Día 2", exerciseIDs: otherRoutine)],
        history: history + [makeSession(today, routine: "DIA1", logs: logs)]
    )
}

@Suite("El selector de ejercicios del entreno")
struct WorkoutPickerRulesTests {
    @Test("para añadir: los del catálogo fuera de la rutina y del entreno, por orden alfabético")
    func addCandidates() {
        let data = data(logs: [makeLog("press_banca"), makeLog("curl")])
        #expect(data.addCandidates(on: today).map(\.id) == ["aperturas", "remo"])
    }

    @Test("se puede cambiar por otro si queda algún ejercicio fuera del entreno")
    func swapCandidates() {
        #expect(data(logs: [makeLog("press_banca")]).hasSwapCandidates(on: today))
        let all = data(logs: ["press_banca", "remo", "curl", "aperturas"].map { makeLog(ExerciseID($0)) })
        #expect(!all.hasSwapCandidates(on: today))
    }

    @Test("crear un ejercicio lo pone en el catálogo con su id; si el nombre ya existe, nada")
    func createExercise() {
        var data = data(logs: [makeLog("press_banca")])
        #expect(data.createExercise(named: "Press Arnold", group: .hombros) == "press_arnold")
        #expect(data.catalog["press_arnold"]?.group == .hombros)
        let before = data
        #expect(data.createExercise(named: "press  arnold", group: nil) == nil)
        #expect(data == before)
    }

    @Test("el cambio recíproco: a la otra rutina que tiene el ejercicio nuevo, si no se hizo esta semana")
    func reciprocal() {
        let data = data(logs: [makeLog("remo")])
        let offer = data.reciprocalSwap(from: "DIA1", new: "remo", outgoing: "press_banca", on: today)
        #expect(offer?.routine == "DIA2")
        #expect(offer?.swap == PendingSwap(from: "remo", to: "press_banca", weekStart: today.weekStart))
    }

    @Test("sin cambio recíproco si la otra rutina ya se hizo esta semana o el ejercicio no es de otra")
    func noReciprocal() {
        let done = data(logs: [makeLog("remo")],
                        history: [makeSession(today.adding(days: -1), routine: "DIA2", completed: true)])
        #expect(done.reciprocalSwap(from: "DIA1", new: "remo", outgoing: "press_banca", on: today) == nil)
        let nowhere = data(logs: [makeLog("curl")])
        #expect(nowhere.reciprocalSwap(from: "DIA1", new: "curl", outgoing: "press_banca", on: today) == nil)
    }

    @Test("un cambio pendiente solo vale la semana en que se creó")
    func pendingActive() {
        let pending = PendingSwap(from: "remo", to: "curl", weekStart: today.weekStart)
        #expect(pending.isActive(inWeekStarting: today.weekStart))
        #expect(!pending.isActive(inWeekStarting: today.adding(days: 7).weekStart))
    }
}

@Suite("Progreso: la ventana y la escala")
struct ProgressRulesTests {
    @Test("la ventana de Progreso es de 8 semanas, y la franja de referencia, la de esa ventana")
    func window() {
        #expect(ProgressWindow.weeks == 8)
        #expect(GroupSets.referenceRange(weeks: ProgressWindow.weeks) == 32...80)
    }

    @Test("la escala de las barras: en decenas, nunca por debajo de la franja ni de 10")
    func scale() {
        #expect(GroupSets.scale(largest: 0, reference: 32...80) == 80)
        #expect(GroupSets.scale(largest: 91.5, reference: 32...80) == 100)
        #expect(GroupSets.scale(largest: 3, reference: 0...0) == 10)
    }
}

@Suite("Cómo cambia una sesión respecto a la anterior")
struct SessionChangeTests {
    @Test("las dos con lastre o las dos sin él: el % de la métrica principal")
    func percent() {
        let previous = makeLog(weight: 50, series: 3, expected: 10, actual: [10, 10, 10])
        let current = makeLog(weight: 55, series: 3, expected: 10, actual: [10, 10, 10])
        #expect(current.change(from: previous) == .percent(10))
        #expect(previous.change(from: previous) == nil)
    }

    @Test("una con lastre y la otra no: manda la carga")
    func load() {
        let previous = makeLog(weight: 0, series: 3, expected: 10, actual: [10, 10, 10])
        let current = makeLog(weight: 5, series: 3, expected: 10, actual: [10, 10, 10])
        #expect(current.change(from: previous) == .load(5))
        #expect(previous.change(from: current) == .load(-5))
    }

    @Test("planificar un log rellena las series vacías y las que faltan con el objetivo")
    func planning() {
        let log = ExerciseLog(planning: "press_banca", from: LogSeed(series: 3, targetReps: 10, weight: 50, actualReps: [8, nil]))
        #expect(log.actualReps == [8, 10, 10])
    }
}

@Suite("Series por grupo muscular")
struct GroupSetsRulesTests {
    @Test("dos ejercicios con el mismo nombre son dos filas, no una suma")
    func sameName() {
        let data = TrainingData(
            catalog: Catalog([exercise("remo_a", "Remo", .espalda), exercise("remo_b", "Remo", .espalda)]),
            history: [makeSession(today, completed: true, logs: [makeLog("remo_a", series: 3), makeLog("remo_b", series: 4)])]
        )
        let espalda = data.groupSets(anchor: today).first { $0.group == .espalda }
        #expect(espalda?.exercises.map(\.sets).sorted() == [3, 4])
        #expect(espalda?.sets == 7)
    }
}
