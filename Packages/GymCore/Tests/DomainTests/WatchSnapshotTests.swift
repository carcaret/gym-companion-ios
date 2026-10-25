import Domain
import Testing

// Lo que enseña el reloj (#16): el entreno en curso, ejercicio a ejercicio, con el peso y las reps
// de hoy y las reps de las últimas sesiones terminadas.

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

    @Test("las reps de hoy son las del log; una serie sin rellenar lleva las reps objetivo")
    func todayReps() throws {
        let snapshot = data(history: [active([makeLog(series: 4, expected: 8, actual: [12, nil, 11, nil])])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).exercises[0].reps == [12, 8, 11, 8])
    }

    @Test("una serie añadida sin reps también lleva las reps objetivo")
    func addedSeries() throws {
        let snapshot = data(history: [active([makeLog(series: 4, expected: 10, actual: [12, 12, 11])])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).exercises[0].reps == [12, 12, 11, 10])
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

    @Test("las sesiones anteriores: solo terminadas, de la más reciente a la más antigua, como mucho 4")
    func previous() throws {
        let history = [
            makeSession("2026-10-01", completed: true, logs: [makeLog(actual: [1, 1, 1])]),
            makeSession("2026-10-21", completed: true, logs: [makeLog(actual: [12, 12, 11])]),
            makeSession("2026-10-10", completed: true, logs: [makeLog(actual: [11, 10, 9])]),
            makeSession("2026-10-17", completed: true, logs: [makeLog(actual: [12, 11, nil])]),
            makeSession("2026-10-19", completed: false, logs: [makeLog(actual: [2, 2, 2])]),
            makeSession("2026-10-14", completed: true, logs: [makeLog(actual: [11, 11, 10])]),
            active([makeLog(actual: [12, 12, 12])]),
        ]
        let previous = try #require(data(history: history).watchSnapshot(today: today).workout).exercises[0].previous
        #expect(previous == [
            WatchSnapshot.Previous(date: "2026-10-21", reps: [12, 12, 11]),
            WatchSnapshot.Previous(date: "2026-10-17", reps: [12, 11, nil]),
            WatchSnapshot.Previous(date: "2026-10-14", reps: [11, 11, 10]),
            WatchSnapshot.Previous(date: "2026-10-10", reps: [11, 10, 9]),
        ])
    }

    @Test("las sesiones anteriores son las de ese ejercicio y no cuentan las que se saltó")
    func previousOfExercise() throws {
        let history = [
            makeSession("2026-10-17", completed: true, logs: [makeLog(actual: [9, 9, 9])]),
            makeSession("2026-10-19", completed: true, logs: [makeLog("sentadilla", actual: [5, 5, 5])]),
            makeSession("2026-10-21", completed: true, logs: [makeLog(actual: [10, 10, 10], skipped: true)]),
            active([makeLog()]),
        ]
        let previous = try #require(data(history: history).watchSnapshot(today: today).workout).exercises[0].previous
        #expect(previous == [WatchSnapshot.Previous(date: "2026-10-17", reps: [9, 9, 9])])
    }

    @Test("un ejercicio nunca hecho no tiene sesiones anteriores")
    func neverDone() throws {
        let snapshot = data(history: [active([makeLog()])]).watchSnapshot(today: today)
        #expect(try #require(snapshot.workout).exercises[0].previous.isEmpty)
    }
}
