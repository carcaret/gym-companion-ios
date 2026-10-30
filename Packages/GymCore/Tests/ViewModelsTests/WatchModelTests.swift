import Domain
import GymCoreTesting
import Testing
import ViewModels

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

// La app del reloj como app de entreno (#17, diseño cerrado con el usuario el 2026-10-29). Hasta
// entonces solo enseñaba el entreno (#16): una página por ejercicio con las reps de hoy y las 4
// últimas sesiones; ahora, el plan de hoy, la mejor sesión reciente y la última.

@MainActor
private struct Watch {
    let model: WatchModel
    let recorder = FakeWorkoutRecorder()
    let alert = RecordingRestAlert()

    init(today: LocalDate) {
        model = WatchModel(clock: FixedClock(today), recorder: recorder, restAlert: alert)
    }

    /// Con el entreno recibido y empezado a medir.
    static func recording(_ snapshot: WatchSnapshot, today: LocalDate) async -> Watch {
        let watch = Watch(today: today)
        await watch.model.receive(snapshot)
        await watch.model.start()
        return watch
    }
}

@MainActor
@Suite("Pantalla del reloj")
struct WatchModelTests {
    private let today = LocalDate(year: 2026, month: 10, day: 25)!

    private func exercise(
        _ name: String, weight: Double = 62.5, series: Int = 4, targetReps: Int = 11, skipped: Bool = false,
        best: WatchSnapshot.Reference? = nil, last: WatchSnapshot.Reference? = nil
    ) -> WatchSnapshot.Exercise {
        WatchSnapshot.Exercise(name: name, weight: weight, series: series, targetReps: targetReps, skipped: skipped, best: best, last: last)
    }

    private func workout(_ exercises: [WatchSnapshot.Exercise], routine: String = "Full Body - Día 1", date: LocalDate? = nil) -> WatchSnapshot {
        WatchSnapshot(workout: WatchSnapshot.Workout(date: date ?? today, routineName: routine, exercises: exercises))
    }

    private var threeExercises: WatchSnapshot {
        workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo")])
    }

    private func date(_ iso: String) -> LocalDate {
        LocalDate(iso: iso)!
    }

    // MARK: - Antes de medir

    @Test("hasta recibir algo del iPhone, lo dice")
    func waiting() {
        #expect(Watch(today: today).model.screen == .message("Abre Gym en el iPhone"))
    }

    @Test("sin entreno en curso, pide empezarlo en el iPhone")
    func noWorkout() async {
        let watch = Watch(today: today)
        await watch.model.receive(WatchSnapshot(workout: nil))
        #expect(watch.model.screen == .message("Empieza el entreno en el iPhone"))
    }

    @Test("con el entreno en curso en el iPhone, la rutina y cuántos ejercicios, listo para empezar")
    func ready() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        #expect(watch.model.screen == .ready(WatchModel.Ready(routine: "Full Body - Día 1", detail: "3 ejercicios", error: nil, isStarting: false)))
        #expect(watch.recorder.starts == 0)
    }

    @Test("un entreno de otro día (lo último que llegó, quizá de ayer) no se enseña")
    func staleWorkout() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise("Press Banca")], date: today.adding(days: -1)))
        #expect(watch.model.screen == .message("Empieza el entreno en el iPhone"))
    }

    // MARK: - Los ejercicios

    @Test("cada ejercicio con su nombre, su posición y el plan de hoy")
    func exercises() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise("Press Banca"), exercise("Dominadas", weight: 0, series: 3, targetReps: 8)]))
        #expect(watch.model.exercises.map(\.name) == ["Press Banca", "Dominadas"])
        #expect(watch.model.exercises.map(\.position) == ["1/2", "2/2"])
        #expect(watch.model.exercises.map(\.plan) == ["62,5 kg · 4 × 11", "Peso corporal · 3 × 8"])
    }

    @Test("la mejor sesión reciente: sus reps y su fecha")
    func best() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise("Press Banca", best: WatchSnapshot.Reference(date: date("2026-10-21"), weight: 62.5, reps: [11, 11, 10, 8]))]))
        let exercise = watch.model.exercises[0]
        #expect(exercise.best == WatchModel.Reference(label: "Mejor", detail: "11·11·10·8", date: "21 oct"))
        #expect(exercise.last == nil)
        #expect(exercise.firstTime == nil)
    }

    @Test("la última, cuando no es la mejor: con su peso, que puede no ser el del plan")
    func last() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise(
            "Hammer curl", weight: 16,
            best: WatchSnapshot.Reference(date: date("2026-09-21"), weight: 16, reps: [11, 11, 11]),
            last: WatchSnapshot.Reference(date: date("2026-10-21"), weight: 12, reps: [10, nil, 10])
        )]))
        #expect(watch.model.exercises[0].last == WatchModel.Reference(label: "Última", detail: "12 kg · 10·—·10", date: "21 oct"))
    }

    @Test("un ejercicio nunca hecho dice que es la primera vez")
    func firstTime() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise("Press Banca")]))
        #expect(watch.model.exercises[0].firstTime == "Primera vez")
    }

    @Test("un ejercicio saltado hoy se marca")
    func skipped() async {
        let watch = Watch(today: today)
        await watch.model.receive(workout([exercise("Press Banca", skipped: true), exercise("Remo")]))
        #expect(watch.model.exercises.map(\.isSkipped) == [true, false])
        // Lo dice con un texto, que también lee VoiceOver: antes solo se veía más apagado (repaso
        // de la HIG, 2026-10-28).
        #expect(watch.model.exercises.map(\.status) == ["Saltado", nil])
    }

    @Test("empieza en el primer ejercicio")
    func startsAtFirst() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        #expect(watch.model.exerciseIndex == 0)
        #expect(watch.model.currentExercise?.name == "Press Banca")
    }

    @Test("un cambio del mismo entreno no mueve de ejercicio")
    func keepsExercise() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.exerciseIndex = 2
        await watch.model.receive(workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo", weight: 70)]))
        #expect(watch.model.exerciseIndex == 2)
    }

    @Test("si el entreno se queda con menos ejercicios, va al último")
    func clampsExercise() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.exerciseIndex = 2
        await watch.model.receive(workout([exercise("Press Banca"), exercise("Sentadilla")]))
        #expect(watch.model.exerciseIndex == 1)
    }

    @Test("un entreno nuevo empieza otra vez en el primer ejercicio")
    func newWorkout() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.exerciseIndex = 2
        await watch.model.receive(workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo")], routine: "Full Body - Día 2"))
        #expect(watch.model.exerciseIndex == 0)
    }

    @Test("después de un rato sin entreno, el siguiente empieza en el primer ejercicio")
    func afterNoWorkout() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.exerciseIndex = 2
        await watch.model.receive(WatchSnapshot(workout: nil))
        await watch.model.receive(threeExercises)
        #expect(watch.model.exerciseIndex == 0)
    }

    @Test("la corona cambia de ejercicio sin salirse de los que hay")
    func crown() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.showExercise(at: 1)
        #expect(watch.model.currentExercise?.name == "Sentadilla")
        watch.model.showExercise(at: 5)
        #expect(watch.model.exerciseIndex == 2)
        watch.model.showExercise(at: -1)
        #expect(watch.model.exerciseIndex == 0)
    }

    // MARK: - Medir el entreno

    @Test("empezar mide la sesión y enseña la página del entreno")
    func start() async {
        let watch = await Watch.recording(threeExercises, today: today)
        #expect(watch.recorder.starts == 1)
        #expect(watch.model.screen == .workout)
        #expect(watch.model.tab == .workout)
    }

    @Test("si no se puede empezar a medir, lo dice y se puede volver a intentar")
    func startFails() async {
        let watch = Watch(today: today)
        watch.recorder.failsToStart = true
        await watch.model.receive(threeExercises)
        await watch.model.start()
        guard case .ready(let ready) = watch.model.screen else { Issue.record("no está listo"); return }
        #expect(ready.error == "No se ha podido empezar a medir. Mira los permisos de Salud en el iPhone.")
        watch.recorder.failsToStart = false
        await watch.model.start()
        #expect(watch.model.screen == .workout)
    }

    @Test("empezar otra vez mientras mide no hace nada")
    func startTwice() async {
        let watch = await Watch.recording(threeExercises, today: today)
        await watch.model.start()
        #expect(watch.recorder.starts == 1)
    }

    @Test("el iPhone puede abrir el reloj antes de que llegue el entreno: lo viejo que llega al abrir no lo termina")
    func launchedBeforeSnapshot() async {
        let watch = Watch(today: today)
        await watch.model.start()
        await watch.model.receive(WatchSnapshot(workout: nil))
        #expect(watch.model.screen == .workout)
        await watch.model.receive(threeExercises)
        #expect(watch.model.currentExercise?.name == "Press Banca")
        #expect(watch.recorder.ends == 0)
    }

    @Test("el tiempo es el de la sesión de Salud")
    func elapsed() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(1421)
        #expect(watch.model.time.elapsed == "23:41")
    }

    @Test("lo que mide Salud: el pulso y las kcal, desde cero en cada entreno")
    func metrics() async {
        let watch = await Watch.recording(threeExercises, today: today)
        #expect(watch.model.metrics == WatchModel.Metrics(heartRate: "--", activeEnergy: "0", totalEnergy: "0"))
        watch.recorder.emit(WorkoutMetrics(heartRate: 127.6, activeEnergy: 171.5, totalEnergy: 221))
        #expect(watch.model.metrics == WatchModel.Metrics(heartRate: "128", activeEnergy: "172", totalEnergy: "221"))
    }

    @Test("la medida que llega mientras arranca la sesión no se pierde")
    func metricsWhileStarting() async {
        let watch = Watch(today: today)
        watch.recorder.metricsOnStart = WorkoutMetrics(heartRate: 90, activeEnergy: 1, totalEnergy: 2)
        await watch.model.receive(threeExercises)
        await watch.model.start()
        #expect(watch.model.metrics.heartRate == "90")
    }

    // MARK: - El descanso

    @Test("sin tocar, el descanso está a cero y dice que se toque")
    func restIdle() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(600)
        let time = watch.model.time
        #expect(time.restPhase == .idle)
        #expect(time.rest == "0:00")
        #expect(time.restLabel == "toca para descansar")
    }

    @Test("un toque empieza el descanso y programa la vibración a 1:30")
    func restStarts() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(600)
        watch.model.tapRest()
        watch.recorder.elapsedTime = .seconds(645)
        let time = watch.model.time
        #expect(time.restPhase == .resting)
        #expect(time.rest == "0:45")
        #expect(time.restLabel == "descanso")
        #expect(time.restProgress == 0.5)
        #expect(watch.alert.scheduled == [.seconds(90)])
    }

    @Test("cumplido, sigue contando y dice a por la siguiente")
    func restOverdue() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(600)
        watch.model.tapRest()
        watch.recorder.elapsedTime = .seconds(700)
        let time = watch.model.time
        #expect(time.restPhase == .overdue)
        #expect(time.rest == "1:40")
        #expect(time.restLabel == "a por la siguiente")
        #expect(time.restProgress == 1)
    }

    @Test("a 2:30 vuelve solo a cero")
    func restResets() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(600)
        watch.model.tapRest()
        watch.recorder.elapsedTime = .seconds(750)
        #expect(watch.model.time.restPhase == .idle)
    }

    @Test("un toque mientras cuenta lo para, lo deja a cero y quita la vibración")
    func restStops() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.elapsedTime = .seconds(600)
        watch.model.tapRest()
        watch.recorder.elapsedTime = .seconds(630)
        watch.model.tapRest()
        #expect(watch.model.time.restPhase == .idle)
        #expect(watch.alert.cancellations == 1)
        #expect(watch.alert.scheduled.count == 1)
    }

    @Test("sin medir, tocar el tiempo no hace nada")
    func restWithoutRecording() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        watch.model.tapRest()
        #expect(watch.alert.scheduled.isEmpty)
    }

    // MARK: - Terminar

    @Test("terminar deja de medir, quita la vibración pendiente y enseña el resumen")
    func finish() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.model.tapRest()
        await watch.model.finish()
        #expect(watch.recorder.ends == 1)
        #expect(watch.alert.cancellations == 1)
        #expect(watch.model.screen == .summary(WatchModel.Summary(duration: "50:00", activeEnergy: "412", totalEnergy: "520", averageHeartRate: "118 ppm")))
    }

    @Test("el entreno terminado en el iPhone termina también el del reloj")
    func finishedOnPhone() async {
        let watch = await Watch.recording(threeExercises, today: today)
        await watch.model.receive(WatchSnapshot(workout: nil))
        #expect(watch.recorder.ends == 1)
        guard case .summary = watch.model.screen else { Issue.record("sin resumen"); return }
    }

    @Test("si no se puede guardar, vuelve a la pantalla de empezar")
    func finishFails() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.recorder.failsToEnd = true
        await watch.model.finish()
        guard case .ready = watch.model.screen else { Issue.record("no está listo"); return }
    }

    @Test("sin medir, terminar no hace nada")
    func finishWithoutRecording() async {
        let watch = Watch(today: today)
        await watch.model.receive(threeExercises)
        await watch.model.finish()
        #expect(watch.recorder.ends == 0)
    }

    @Test("«Listo» vuelve a la pantalla de empezar mientras el entreno siga abierto en el iPhone")
    func dismissSummary() async {
        let watch = await Watch.recording(threeExercises, today: today)
        watch.model.tab = .controls
        await watch.model.finish()
        watch.model.dismissSummary()
        guard case .ready = watch.model.screen else { Issue.record("no está listo"); return }
        await watch.model.start()
        #expect(watch.model.tab == .workout)
        #expect(watch.recorder.starts == 2)
    }

    @Test("«Listo» con el entreno ya terminado en el iPhone pide empezar otro")
    func dismissAfterPhone() async {
        let watch = await Watch.recording(threeExercises, today: today)
        await watch.model.receive(WatchSnapshot(workout: nil))
        watch.model.dismissSummary()
        #expect(watch.model.screen == .message("Empieza el entreno en el iPhone"))
    }
}
