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
    @Test("la ventana de Progreso es de 8 semanas, y la franja de referencia, de 10 a 20 series por semana")
    func window() {
        #expect(ProgressWindow.weeks == 8)
        #expect(GroupSets.weeklyReferenceRange == 10...20)
    }

    // Decisión del usuario, 2026-11-27 (#112): con «estancado en cuanto la última sesión no bate el
    // récord», salían 12 de 20 y casi siempre entre 8 y 14; a su ritmo, no batirlo una vez es lo normal.
    @Test("estancado es llevar al menos 3 sesiones y 28 días sin superar el récord; la comparación, hace 3 meses")
    func stallThreshold() {
        #expect(StallThreshold.minimumSessionsWithoutRecord == 3)
        #expect(StallThreshold.minimumDaysWithoutRecord == 28)
        #expect(ProgressWindow.lookBackMonths == 3)
    }

    @Test("la escala de las barras: en medias decenas, con otra media decena por encima de la franja")
    func scale() {
        #expect(GroupSets.scale(largestPerWeek: 0) == 25)
        #expect(GroupSets.scale(largestPerWeek: 12.8) == 25)
        #expect(GroupSets.scale(largestPerWeek: 27.3) == 30)
        #expect(GroupSets.scale(largestPerWeek: 3, reference: 0...0) == 5)
    }

    @Test("las series por semana de un grupo suman las directas y las indirectas")
    func perWeek() {
        let data = TrainingData(
            catalog: Catalog([exercise("curl_biceps_polea", "Curl polea", .biceps), exercise("jalon_al_pecho_neutro", "Jalón neutro", .espalda)]),
            history: [makeSession("2026-06-19", completed: true, logs: [
                makeLog("curl_biceps_polea", weight: 20, series: 4, expected: 10, actual: [10]),
                makeLog("jalon_al_pecho_neutro", weight: 60, series: 4, expected: 10, actual: [10]),
            ])]
        )
        let biceps = data.groupSets(anchor: "2026-06-19", weeks: 8).first { $0.group == .biceps }
        #expect(biceps?.totalPerWeek(weeks: 8) == 0.75)
    }
}

@Suite("Progreso: el estancamiento")
struct StallRulesTests {
    private func data(_ sessions: [(LocalDate, Double, [Int?])]) -> TrainingData {
        TrainingData(catalog: Catalog([exercise("press", "Press", .hombros)]),
                     history: sessions.map { makeSession($0.0, completed: true, logs: [makeLog("press", weight: $0.1, series: 3, expected: 10, actual: $0.2)]) })
    }

    // Decisión del usuario, 2026-11-02: con las elevaciones laterales a 14 kg y cuatro sesiones
    // iguales, Progreso decía «12 → 14 kg» porque la subida caía en la ventana. La última sesión,
    // del 3/7 al 10/7, para que el récord tenga los 28 días del umbral (2026-11-27).
    @Test("subir de peso no tapa lo que se estanca después al peso nuevo")
    func weightUpThenStall() {
        let r = data([("2026-06-05", 12, [12, 12, 12]), ("2026-06-12", 14, [11, 11, 11]), ("2026-06-19", 14, [11, 11, 11]),
                      ("2026-06-26", 14, [11, 11, 11]), ("2026-07-10", 14, [11, 11, 11])])
            .progress(of: "press", anchor: "2026-07-10", weeks: 8)
        #expect(r.status == .stalled)
        #expect(r.stallSessions == 4)
        #expect(r.sessionsWithoutRecord == 3)
        #expect(r.spanDays == nil)
    }

    @Test("la primera sesión a un peso nuevo es progreso, y su frase cuenta desde la carga vieja")
    func firstAtNewWeight() {
        let r = data([("2026-06-05", 12, [12, 12, 12]), ("2026-06-12", 12, [12, 12, 12]), ("2026-06-19", 14, [10, 10, 10])])
            .progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.spanDays == 7)
    }

    @Test("las últimas sesiones traen su día")
    func recentDates() {
        let r = data([("2026-06-05", 12, [10]), ("2026-06-12", 12, [11]), ("2026-06-19", 12, [12]), ("2026-06-26", 12, [12])])
            .progress(of: "press", anchor: "2026-06-26", weeks: 8)
        #expect(r.recentSessions.map(\.date) == ["2026-06-12", "2026-06-19", "2026-06-26"])
    }

    // El umbral (decisión del usuario, 2026-11-27): hacen falta las dos condiciones. El mínimo de
    // sesiones evita que un parón o un ejercicio saltado lo marque con una o dos.
    @Test("3 sesiones y 28 días sin superar el récord es estancado")
    func threshold() {
        let r = data([("2026-06-05", 18, [12, 12, 12]), ("2026-06-12", 18, [12, 12, 11]), ("2026-06-19", 18, [12, 11, 11]),
                      ("2026-06-26", 18, [12, 12, 11])])
            .progress(of: "press", anchor: "2026-07-03", weeks: 8)
        #expect(r.status == .stalled)
        #expect(r.sessionsWithoutRecord == 3)
        #expect(r.stallSince == "2026-06-05")
    }

    @Test("2 sesiones sin superar el récord no es estancado, aunque pasen 40 días")
    func twoSessions() {
        let r = data([("2026-05-01", 18, [10, 10, 10]), ("2026-05-24", 18, [12, 12, 12]), ("2026-06-19", 18, [12, 12, 11]),
                      ("2026-06-26", 18, [12, 11, 11])])
            .progress(of: "press", anchor: "2026-07-03", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.stallSessions == 0)
        #expect(r.stallSince == nil)
    }

    @Test("3 sesiones sin superar el récord en 21 días no es estancado")
    func twentyOneDays() {
        let r = data([("2026-06-12", 18, [12, 12, 12]), ("2026-06-19", 18, [12, 12, 11]), ("2026-06-26", 18, [12, 11, 11]),
                      ("2026-07-03", 18, [12, 12, 11])])
            .progress(of: "press", anchor: "2026-07-03", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.stallSessions == 0)
    }

    // Lo que no llega al umbral sale como «progresa», con lo avanzado en la ventana hasta el récord
    // (decisión del usuario, 2026-11-27, opción (a) de #112).
    @Test("sin llegar al umbral, lo avanzado en la ventana llega hasta el récord")
    func belowThresholdReps() {
        let r = data([("2026-06-05", 18, [11, 11, 11]), ("2026-06-12", 18, [12, 12, 11]), ("2026-06-19", 18, [12, 11, 11]),
                      ("2026-06-26", 18, [12, 11, 10])])
            .progress(of: "press", anchor: "2026-06-26", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.repsFrom == 33)
        #expect(r.repsTo == 35)
        #expect(r.bestReps == 35)
        #expect(r.sessionsWithoutRecord == 2)
    }

    @Test("sin llegar al umbral tras subir de peso, la frase cuenta la subida desde la carga vieja")
    func belowThresholdWeight() {
        let r = data([("2026-06-05", 16, [12, 12, 12]), ("2026-06-12", 16, [12, 12, 12]), ("2026-06-19", 18, [10, 10, 10]),
                      ("2026-06-26", 18, [10, 10, 9])])
            .progress(of: "press", anchor: "2026-06-26", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.weightFrom == 16)
        #expect(r.weightTo == 18)
        #expect(r.spanDays == 14)
    }
}

// Qué cambió desde el récord, en los estancados (decisión del usuario, 2026-11-27, #112). Compara
// la misma serie entre la sesión del récord y la última; no es la caída de la 1.ª a la última dentro
// de una sesión, que el diseño de Estadísticas de la PWA descartó como señal.
@Suite("Progreso: las series desde el récord")
struct SetsChangeRulesTests {
    private func stalled(record: [Int?], last: [Int?]) -> ExerciseProgress {
        // Las de antes y las de en medio, una rep menos en cada serie: el récord es el del 8/5.
        let below = record.map { $0.map { $0 - 1 } }
        let sessions: [(LocalDate, [Int?])] = [("2026-05-01", below), ("2026-05-08", record), ("2026-05-15", below),
                                               ("2026-05-22", below), ("2026-06-05", last)]
        return TrainingData(catalog: Catalog([exercise("press", "Press", .pecho)]),
                            history: sessions.map { makeSession($0.0, completed: true, logs: [makeLog("press", weight: 30, series: 4, expected: 10, actual: $0.1)]) })
            .progress(of: "press", anchor: "2026-06-05", weeks: 8)
    }

    @Test("compara la 1.ª y la última serie del récord con las de la última sesión")
    func changed() {
        let r = stalled(record: [11, 11, 10, 8], last: [12, 11, 7, 6])
        #expect(r.status == .stalled)
        #expect(r.setsChange == SetsChange(firstFrom: 11, firstTo: 12, lastFrom: 8, lastTo: 6))
    }

    @Test("basta con que cambie una de las dos")
    func oneChanged() {
        #expect(stalled(record: [12, 12, 11], last: [12, 12, 9]).setsChange == SetsChange(firstFrom: 12, firstTo: 12, lastFrom: 11, lastTo: 9))
    }

    @Test("con las dos iguales no hay nada que contar")
    func identical() {
        #expect(stalled(record: [14, 14, 14], last: [14, 14, 14]).setsChange == nil)
        #expect(stalled(record: [11, 11, 10, 8], last: [11, 10, 9, 8]).setsChange == nil)
    }

    @Test("con una sola serie no sale: la frase ya lo dice")
    func singleSet() {
        #expect(stalled(record: [20], last: [18]).setsChange == nil)
    }

    @Test("en los que progresan no sale")
    func progressing() {
        let r = TrainingData(catalog: Catalog([exercise("press", "Press", .pecho)]),
                             history: [("2026-06-05", [10, 10, 9]), ("2026-06-12", [11, 10, 9]), ("2026-06-19", [10, 10, 8]), ("2026-06-26", [12, 10, 9])]
                                .map { makeSession(LocalDate($0.0), completed: true, logs: [makeLog("press", weight: 30, series: 3, expected: 10, actual: $0.1)]) })
            .progress(of: "press", anchor: "2026-06-26", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.setsChange == nil)
    }
}

// Hace 3 meses, al abrir un ejercicio (decisión del usuario, 2026-11-27, #112): cuando el avance se
// ralentiza, en 8 semanas parece parado y en 3 meses se ve lo que ha subido.
@Suite("Progreso: hace 3 meses")
struct LookBackRulesTests {
    private func data(_ sessions: [(LocalDate, Double, [Int?])]) -> TrainingData {
        TrainingData(catalog: Catalog([exercise("press", "Press", .hombros)]),
                     history: sessions.map { makeSession($0.0, completed: true, logs: [makeLog("press", weight: $0.1, series: 3, expected: 10, actual: $0.2)]) })
    }

    @Test("la última sesión con reps en esa fecha o antes")
    func lastOnOrBefore() {
        let r = data([("2026-08-12", 16, [16, 16, 15]), ("2026-08-19", 16, [16, 15, 15]), ("2026-08-26", 16, [16, 16, 16]),
                      ("2026-11-19", 18, [14, 14, 14])])
            .progress(of: "press", anchor: "2026-11-19", weeks: 8)
        #expect(r.lookBack?.date == "2026-08-19")
        #expect(r.lookBack?.log.weight == 16)
        #expect(r.lookBack?.log.actualReps == [16, 15, 15])
    }

    @Test("salta las sesiones sin reps")
    func skipsEmpty() {
        let r = data([("2026-08-12", 16, [16, 16, 15]), ("2026-08-19", 16, [nil, nil, nil]), ("2026-11-19", 18, [14, 14, 14])])
            .progress(of: "press", anchor: "2026-11-19", weeks: 8)
        #expect(r.lookBack?.date == "2026-08-12")
    }

    @Test("sin sesiones tan antiguas no hay nada")
    func noneThatOld() {
        let r = data([("2026-08-20", 16, [16, 16, 15]), ("2026-11-19", 18, [14, 14, 14])])
            .progress(of: "press", anchor: "2026-11-19", weeks: 8)
        #expect(r.lookBack == nil)
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

@Suite("Cómo queda una serie respecto al objetivo")
struct RepOutcomeTests {
    @Test("por debajo, justo o por encima del objetivo; llegar a él es cumplirlo")
    func outcome() {
        #expect(RepOutcome(reps: 8, target: 10) == .below)
        #expect(RepOutcome(reps: 10, target: 10) == .atTarget)
        #expect(RepOutcome(reps: 12, target: 10) == .above)
        #expect(!RepOutcome.below.meetsTarget && RepOutcome.atTarget.meetsTarget && RepOutcome.above.meetsTarget)
    }
}
