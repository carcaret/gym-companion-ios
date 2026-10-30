import Domain
import Testing

// Lo que enseña el reloj: el entreno en curso, ejercicio a ejercicio, con el plan de hoy y las
// sesiones de referencia: la mejor reciente y la última (decisión del usuario, 2026-10-29).

@Suite("Lo que enseña el reloj")
struct WatchSnapshotTests {
    private let today: LocalDate = "2026-10-25"

    private func data(history: [Session], routine: [ExerciseID] = ["press_banca", "sentadilla"]) -> TrainingData {
        TrainingData(
            catalog: Catalog([exercise("press_banca", "Press Banca"), exercise("sentadilla", "Sentadilla")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: routine)],
            history: history
        )
    }

    private func active(_ logs: [ExerciseLog]) -> Session {
        makeSession(today, completed: false, logs: logs)
    }

    private func done(_ date: LocalDate, _ log: ExerciseLog) -> Session {
        makeSession(date, completed: true, logs: [log])
    }

    private func firstExercise(in history: [Session]) throws -> WatchSnapshot.Exercise {
        try #require(data(history: history).watchSnapshot(today: today).workout).exercises[0]
    }

    @Test("sin sesión hoy, no hay entreno")
    func noSession() {
        let snapshot = data(history: [makeSession("2026-10-21", completed: true, logs: [makeLog()])]).watchSnapshot(today: today)
        #expect(snapshot.workout == nil)
    }

    @Test("con el entreno de hoy terminado, no hay entreno en curso")
    func finishedToday() {
        let snapshot = data(history: [makeSession(today, completed: true, logs: [makeLog(actual: [10, 10, 10])])]).watchSnapshot(today: today)
        #expect(snapshot.workout == nil)
    }

    @Test("una sesión sin terminar de otro día no es el entreno en curso")
    func unfinishedOtherDay() {
        let snapshot = data(history: [makeSession("2026-10-24", completed: false, logs: [makeLog()])]).watchSnapshot(today: today)
        #expect(snapshot.workout == nil)
    }

    @Test("el entreno en curso: el día, la rutina y sus ejercicios en el orden de la sesión, con nombre y peso")
    func activeWorkout() throws {
        let snapshot = data(history: [active([makeLog("sentadilla", weight: 80), makeLog("press_banca", weight: 62.5)])])
            .watchSnapshot(today: today)
        let workout = try #require(snapshot.workout)
        #expect(workout.date == today)
        #expect(workout.routineName == "Full Body - Día 1")
        #expect(workout.exercises.map(\.name) == ["Sentadilla", "Press Banca"])
        #expect(workout.exercises.map(\.weight) == [80, 62.5])
    }

    @Test("el plan de hoy: las series y las reps objetivo, aunque ya haya reps apuntadas")
    func plan() throws {
        let exercise = try firstExercise(in: [active([makeLog(series: 4, expected: 8, actual: [12, nil, 11, nil])])])
        #expect(exercise.series == 4)
        #expect(exercise.targetReps == 8)
    }

    @Test("un ejercicio saltado hoy se marca")
    func skipped() throws {
        let snapshot = data(history: [active([makeLog(skipped: true), makeLog("sentadilla")])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).exercises.map(\.skipped) == [true, false])
    }

    @Test("un ejercicio fuera del catálogo se llama por su id")
    func unknownExercise() throws {
        let snapshot = data(history: [active([makeLog("remo")])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).exercises[0].name == "remo")
    }

    @Test("una rutina que ya no existe se llama por su id")
    func unknownRoutine() throws {
        let snapshot = data(history: [makeSession(today, routine: "DIA9", completed: false, logs: [makeLog()])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).routineName == "DIA9")
    }

    @Test("la mejor es la de la semilla del plan: más peso; a igualdad, más volumen; con su fecha, peso y reps")
    func best() throws {
        let exercise = try firstExercise(in: [
            done("2026-10-01", makeLog(weight: 60, actual: [12, 12, 12])),
            done("2026-10-08", makeLog(weight: 62.5, actual: [10, 9, 8])),
            done("2026-10-15", makeLog(weight: 62.5, actual: [11, 10, 10])),
            done("2026-10-21", makeLog(weight: 62.5, actual: [10, 9, 8])),
            active([makeLog(weight: 62.5)]),
        ])
        #expect(exercise.best == WatchSnapshot.Reference(date: "2026-10-15", weight: 62.5, reps: [11, 10, 10]))
    }

    @Test("la última, solo si no es la mejor")
    func last() throws {
        let exercise = try firstExercise(in: [
            done("2026-10-14", makeLog(weight: 16, actual: [11, 11, 11])),
            done("2026-10-21", makeLog(weight: 12, actual: [10, 10, 10])),
            active([makeLog(weight: 16)]),
        ])
        #expect(exercise.best?.date == "2026-10-14")
        #expect(exercise.last == WatchSnapshot.Reference(date: "2026-10-21", weight: 12, reps: [10, 10, 10]))
    }

    @Test("si la última es la mejor, no se repite")
    func lastIsBest() throws {
        let exercise = try firstExercise(in: [
            done("2026-10-14", makeLog(weight: 60, actual: [10, 10, 10])),
            done("2026-10-21", makeLog(weight: 62.5, actual: [10, 10, 10])),
            active([makeLog(weight: 62.5)]),
        ])
        #expect(exercise.best?.date == "2026-10-21")
        #expect(exercise.last == nil)
    }

    @Test("no cuentan las sesiones sin terminar, las saltadas ni las de otros ejercicios")
    func onlyCompletedOfExercise() throws {
        let exercise = try firstExercise(in: [
            done("2026-10-17", makeLog(weight: 50, actual: [9, 9, 9])),
            makeSession("2026-10-19", completed: false, logs: [makeLog(weight: 90, actual: [10, 10, 10])]),
            done("2026-10-20", makeLog("sentadilla", weight: 100, actual: [5, 5, 5])),
            done("2026-10-21", makeLog(weight: 80, actual: [10, 10, 10], skipped: true)),
            active([makeLog()]),
        ])
        #expect(exercise.best == WatchSnapshot.Reference(date: "2026-10-17", weight: 50, reps: [9, 9, 9]))
        #expect(exercise.last == nil)
    }

    @Test("sin sesiones en las últimas 6 semanas no hay mejor, pero sí la última")
    func dormant() throws {
        let exercise = try firstExercise(in: [done("2026-08-01", makeLog(weight: 40, actual: [12, 12, 12])), active([makeLog()])])
        #expect(exercise.best == nil)
        #expect(exercise.last == WatchSnapshot.Reference(date: "2026-08-01", weight: 40, reps: [12, 12, 12]))
    }

    @Test("un ejercicio nunca hecho no tiene referencias")
    func neverDone() throws {
        let exercise = try firstExercise(in: [active([makeLog()])])
        #expect(exercise.best == nil)
        #expect(exercise.last == nil)
    }
}

/// Lo que se compara en el reloj: solo las sesiones con el peso de hoy (decisión del usuario,
/// 2026-10-30): las reps de otro peso no dicen nada de la serie que toca.
@Suite("Las referencias con el peso de hoy")
struct WatchReferenceWeightTests {
    private func reference(_ weight: Double, _ reps: [Int?] = [10, 10, 10]) -> WatchSnapshot.Reference {
        WatchSnapshot.Reference(date: "2026-10-21", weight: weight, reps: reps)
    }

    private func exercise(weight: Double = 60, best: WatchSnapshot.Reference?, last: WatchSnapshot.Reference?) -> WatchSnapshot.Exercise {
        WatchSnapshot.Exercise(name: "Press Banca", weight: weight, series: 3, targetReps: 10, skipped: false, best: best, last: last)
    }

    @Test("la mejor y la última con el peso de hoy se enseñan")
    func sameWeight() {
        let exercise = exercise(best: reference(60, [10, 10, 8]), last: reference(60, [10, 10, 9]))
        #expect(exercise.bestAtTodayWeight == reference(60, [10, 10, 8]))
        #expect(exercise.lastAtTodayWeight == reference(60, [10, 10, 9]))
        #expect(!exercise.isFirstTime)
    }

    @Test("con otro peso no se enseñan, y tampoco es la primera vez")
    func otherWeight() {
        let exercise = exercise(weight: 62.5, best: reference(60), last: reference(55))
        #expect(exercise.bestAtTodayWeight == nil)
        #expect(exercise.lastAtTodayWeight == nil)
        #expect(!exercise.isFirstTime)
    }

    @Test("sin ninguna sesión, es la primera vez")
    func firstTime() {
        #expect(exercise(best: nil, last: nil).isFirstTime)
    }
}
