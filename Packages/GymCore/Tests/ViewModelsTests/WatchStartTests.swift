import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Empezar el entreno en el reloj (decisión del usuario, 2026-11-03, sobre un prototipo): sin entreno
// en curso, las rutinas con su color; al tocar una, su pantalla con «Empezar», que mide en seguida y
// pide al iPhone que la empiece. Con el de hoy terminado, pregunta antes de sustituirlo.

@MainActor
@Suite("Empezar en el reloj")
struct WatchStartTests {
    private let today = LocalDate(year: 2026, month: 11, day: 3)!

    private func plan(_ routine: String, _ exercises: [String], date: LocalDate? = nil) -> WatchSnapshot.Workout {
        WatchSnapshot.Workout(date: date ?? today, routineName: routine, exercises: exercises.map {
            WatchSnapshot.Exercise(name: $0, weight: 60, series: 3, targetReps: 10, skipped: false, best: nil, last: nil)
        })
    }

    private func routines(completed: String? = nil, date: LocalDate? = nil, includeEmpty: Bool = false) -> WatchSnapshot {
        var routines = [
            WatchSnapshot.Routine(id: "DIA1", plan: plan("Día 1", ["Press Banca", "Remo"], date: date)),
            WatchSnapshot.Routine(id: "DIA2", plan: plan("Día 2", ["Sentadilla"], date: date)),
        ]
        if includeEmpty { routines.insert(WatchSnapshot.Routine(id: "NUEVA", plan: plan("Nueva", [], date: date)), at: 1) }
        return WatchSnapshot(workout: nil, start: WatchSnapshot.Start(date: date ?? today, routines: routines, completedRoutineName: completed))
    }

    private var dayTwoActive: WatchSnapshot {
        WatchSnapshot(workout: plan("Día 2", ["Sentadilla"]))
    }

    private func chosen(_ routine: RoutineID = "DIA2", _ snapshot: WatchSnapshot? = nil) async -> WatchHarness {
        let watch = WatchHarness(today: today)
        await watch.model.receive(snapshot ?? routines())
        watch.model.choose(routine)
        return watch
    }

    // MARK: - La lista

    @Test("sin entreno en curso, las rutinas en su orden y con el color de cada una")
    func list() async {
        let watch = WatchHarness(today: today)
        await watch.model.receive(routines())
        #expect(watch.model.screen == .routines([
            WatchModel.RoutineRow(id: "DIA1", name: "Día 1", tint: .day1),
            WatchModel.RoutineRow(id: "DIA2", name: "Día 2", tint: .day2),
        ]))
    }

    @Test("una rutina sin ejercicios no sale: no hay nada que medir (y las demás no cambian de color)")
    func emptyRoutine() async {
        let watch = WatchHarness(today: today)
        await watch.model.receive(routines(includeEmpty: true))
        guard case .routines(let rows) = watch.model.screen else { Issue.record("sin lista"); return }
        #expect(rows.map(\.id) == ["DIA1", "DIA2"])
        #expect(rows.map(\.tint) == [.day1, .day2])
    }

    @Test("de un iPhone con la app de antes, sin rutinas, pide empezar en el iPhone")
    func withoutRoutines() async {
        let watch = WatchHarness(today: today)
        await watch.model.receive(WatchSnapshot(workout: nil))
        #expect(watch.model.screen == .message("Empieza el entreno en el iPhone"))
    }

    // MARK: - La pantalla de «Empezar»

    @Test("tocar una rutina abre su pantalla de «Empezar»: el nombre y sus ejercicios, sin medir aún")
    func choose() async {
        let watch = await chosen("DIA1")
        #expect(watch.model.chosen == WatchModel.Ready(routine: "Día 1", detail: "Press Banca · Remo", error: nil, isStarting: false, tint: .day1))
        #expect(watch.recorder.starts == 0)
        #expect(watch.phoneStarter.requests.isEmpty)
    }

    @Test("volver deja la lista como estaba")
    func back() async {
        let watch = await chosen()
        watch.model.closeChosen()
        #expect(watch.model.chosen == nil)
        guard case .routines = watch.model.screen else { Issue.record("sin lista"); return }
    }

    @Test("una rutina que no está en la lista no se abre")
    func unknown() async {
        let watch = await chosen("BORRADA")
        #expect(watch.model.chosen == nil)
    }

    @Test("si la rutina elegida deja de estar (cambiada en el iPhone), vuelve a la lista")
    func chosenRemoved() async {
        let watch = await chosen()
        await watch.model.receive(WatchSnapshot(workout: nil, start: WatchSnapshot.Start(
            date: today, routines: [WatchSnapshot.Routine(id: "DIA1", plan: plan("Día 1", ["Press Banca"]))], completedRoutineName: nil
        )))
        #expect(watch.model.chosen == nil)
    }

    // MARK: - Empezar

    @Test("«Empezar» mide en seguida, enseña sus ejercicios y pide al iPhone que la empiece hoy")
    func start() async {
        let watch = await chosen()
        await watch.model.requestStartChosen()
        #expect(watch.recorder.starts == 1)
        #expect(watch.recorder.days == [today])
        #expect(watch.model.screen == .workout)
        #expect(watch.model.chosen == nil)
        #expect(watch.model.exercises.map(\.name) == ["Sentadilla"])
        #expect(watch.phoneStarter.requests == [PhoneWorkoutStart(routine: "DIA2", day: today)])
    }

    @Test("el plan de otro día (lo último que llegó era de ayer) se empieza hoy")
    func staleStart() async {
        let watch = await chosen("DIA2", routines(date: today.adding(days: -1)))
        await watch.model.requestStartChosen()
        #expect(watch.phoneStarter.requests == [PhoneWorkoutStart(routine: "DIA2", day: today)])
        await watch.model.confirmFinish()
        #expect(watch.phone.requests == [today])
    }

    @Test("si no se puede medir, lo dice en su pantalla y no pide nada al iPhone")
    func startFails() async {
        let watch = await chosen()
        watch.recorder.failsToStart = true
        await watch.model.requestStartChosen()
        #expect(watch.model.chosen?.error == WatchText.startFailed)
        #expect(watch.phoneStarter.requests.isEmpty)
        watch.recorder.failsToStart = false
        await watch.model.requestStartChosen()
        #expect(watch.model.screen == .workout)
    }

    @Test("con el entreno de hoy terminado, pregunta antes de sustituirlo, como en el iPhone")
    func replace() async throws {
        let watch = await chosen("DIA2", routines(completed: "Día 1"))
        await watch.model.requestStartChosen()
        let prompt = try #require(watch.model.replacePrompt)
        #expect(prompt == WatchModel.ReplacePrompt(title: "Ya has entrenado hoy (Día 1)", message: "Si empiezas Día 2, sustituye al entreno de hoy."))
        #expect(watch.recorder.starts == 0)
        await watch.model.confirmReplace(prompt)
        #expect(watch.model.replacePrompt == nil)
        #expect(watch.model.screen == .workout)
        #expect(watch.phoneStarter.requests == [PhoneWorkoutStart(routine: "DIA2", day: today)])
    }

    @Test("sin sustituir, ni mide ni pide nada")
    func cancelReplace() async {
        let watch = await chosen("DIA2", routines(completed: "Día 1"))
        await watch.model.requestStartChosen()
        watch.model.cancelReplace()
        #expect(watch.model.replacePrompt == nil)
        #expect(watch.model.chosen != nil)
        #expect(watch.recorder.starts == 0)
        #expect(watch.phoneStarter.requests.isEmpty)
    }

    @Test("lo terminado otro día no se sustituye: no pregunta")
    func completedOtherDay() async {
        let watch = await chosen("DIA2", routines(completed: "Día 1", date: today.adding(days: -1)))
        await watch.model.requestStartChosen()
        #expect(watch.model.replacePrompt == nil)
        #expect(watch.model.screen == .workout)
    }

    // MARK: - Con el iPhone

    @Test("lo que llega sin entreno antes de que el iPhone lo empiece no lo termina; después, sí")
    func beforePhone() async {
        let watch = await chosen()
        await watch.model.requestStartChosen()
        await watch.model.receive(routines())
        #expect(watch.model.screen == .workout)
        #expect(watch.recorder.ends == 0)
        await watch.model.receive(dayTwoActive)
        #expect(watch.model.screen == .workout)
        // Terminado en el iPhone.
        await watch.model.receive(routines(completed: "Día 2"))
        #expect(watch.recorder.ends == 1)
    }

    @Test("terminar aquí lo empezado aquí pide al iPhone que lo termine")
    func finishStartedHere() async {
        let watch = await chosen()
        await watch.model.requestStartChosen()
        await watch.model.confirmFinish()
        #expect(watch.phone.requests == [today])
    }

    @Test("si mientras se elige se empieza en el iPhone, se deja de elegir y se enseña ese")
    func startedOnPhone() async {
        let watch = await chosen("DIA1")
        await watch.model.receive(dayTwoActive)
        #expect(watch.model.chosen == nil)
        #expect(watch.model.screen == .ready(WatchModel.Ready(routine: "Día 2", detail: "1 ejercicio", error: nil, isStarting: false)))
    }

    @Test("después del resumen, otra vez las rutinas")
    func afterSummary() async {
        let watch = await chosen()
        await watch.model.requestStartChosen()
        await watch.model.receive(dayTwoActive)
        await watch.model.confirmFinish()
        await watch.model.receive(routines(completed: "Día 2"))
        watch.model.dismissSummary()
        guard case .routines = watch.model.screen else { Issue.record("sin lista"); return }
    }
}
