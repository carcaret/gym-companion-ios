import Application
import Domain
import Observation
import Presentation

/// La app del reloj: la app de entreno. Con el entreno en curso que llega del iPhone (`receive`),
/// mide la sesión en Salud (`WorkoutRecorder`) y enseña el tiempo, el descanso y el ejercicio que
/// se elige con la corona. El reloj no hace nada por su cuenta: ni avanza de ejercicio ni sigue lo
/// que se apunta en el iPhone. Un entreno de otro día ya no está en curso.
@MainActor
@Observable
public final class WatchModel {
    private enum Phase: Hashable {
        case idle, starting, recording, ending
        case summary(Summary)
    }

    private struct WorkoutKey: Hashable {
        let date: LocalDate
        let routineName: String
    }

    public private(set) var exercises: [Exercise] = []
    /// El ejercicio que se ve, por posición (la corona).
    public private(set) var exerciseIndex = 0
    public var tab: Tab = .workout
    /// La alerta de «Terminar».
    public private(set) var isFinishPromptPresented = false
    public private(set) var metrics = Metrics(WorkoutMetrics())

    private var phase: Phase = .idle
    /// Hasta recibir algo del iPhone.
    private var waiting = true
    /// Qué entreno se ve: si cambia, se vuelve al primer ejercicio.
    private var shownWorkout: WorkoutKey?
    private var startError: String?
    private var rest = RestTimer()

    private let clock: any Clock
    private let recorder: any WorkoutRecorder
    private let restAlert: any RestAlert

    public init(clock: any Clock, recorder: any WorkoutRecorder, restAlert: any RestAlert) {
        self.clock = clock
        self.recorder = recorder
        self.restAlert = restAlert
        recorder.onMetrics = { [weak self] in self?.metrics = Metrics($0) }
    }

    public var screen: Screen {
        switch phase {
        case .recording, .ending:
            return .workout
        case .summary(let summary):
            return .summary(summary)
        case .idle, .starting:
            guard let shownWorkout else { return .message(waiting ? WatchText.waiting : WatchText.noWorkout) }
            return .ready(Ready(routine: shownWorkout.routineName, detail: WatchText.exerciseCount(exercises.count),
                                error: startError, isStarting: phase == .starting))
        }
    }

    public var currentExercise: Exercise? {
        exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex] : nil
    }

    /// Se lee cada segundo: depende del tiempo que lleva la sesión.
    public var time: Time {
        let now = recorder.elapsed()
        let state = rest.state(at: now)
        let (resting, restPhase, progress): (Duration, RestPhase, Double) = switch state {
        case .idle: (.zero, .idle, 0)
        case .resting(let elapsed): (elapsed, .resting, elapsed / RestTimer.alertAfter)
        case .overdue(let elapsed): (elapsed, .overdue, 1)
        }
        return Time(elapsed: WatchText.duration(now), rest: WatchText.duration(resting), restLabel: WatchText.restLabel(state),
                    restPhase: restPhase, restProgress: progress)
    }

    /// Lo último del iPhone. Si se estaba midiendo y el entreno ha terminado allí, se termina aquí.
    public func receive(_ snapshot: WatchSnapshot) async {
        waiting = false
        guard let workout = snapshot.workout, workout.date == clock.today() else {
            let hadWorkout = shownWorkout != nil
            shownWorkout = nil
            exercises = []
            exerciseIndex = 0
            if hadWorkout { await finish() }
            return
        }
        let key = WorkoutKey(date: workout.date, routineName: workout.routineName)
        if key != shownWorkout {
            shownWorkout = key
            exerciseIndex = 0
        }
        let count = workout.exercises.count
        exerciseIndex = min(exerciseIndex, max(count - 1, 0))
        exercises = workout.exercises.enumerated().map { index, exercise in
            Exercise(
                id: index,
                name: exercise.name,
                position: WatchText.position(index, of: count),
                weight: WatchText.weight(exercise.weight),
                bestReps: exercise.bestAtTodayWeight.map { LogText.reps($0.reps) },
                lastReps: exercise.lastAtTodayWeight.map { LogText.reps($0.reps) },
                isSkipped: exercise.skipped,
                status: exercise.skipped ? WatchText.skipped : nil,
                firstTime: exercise.isFirstTime ? WatchText.firstTime : nil
            )
        }
    }

    /// La corona: el ejercicio en esa posición, sin salirse de los que hay.
    public func showExercise(at index: Int) {
        exerciseIndex = min(max(index, 0), max(exercises.count - 1, 0))
    }

    /// «Empezar» en el reloj, o el iPhone que abre la app para el entreno.
    public func start() async {
        switch phase {
        case .idle, .summary: break
        case .starting, .recording, .ending: return
        }
        phase = .starting
        startError = nil
        // Antes de empezar: la primera medida puede llegar mientras arranca.
        metrics = Metrics(WorkoutMetrics())
        do {
            try await recorder.start(on: clock.today())
        } catch {
            phase = .idle
            startError = WatchText.startFailed
            return
        }
        rest = RestTimer()
        tab = .workout
        phase = .recording
    }

    /// Un toque en el tiempo o el doble toque: a cero, empieza el descanso; contando, lo para.
    public func tapRest() {
        guard phase == .recording else { return }
        let now = recorder.elapsed()
        rest.tap(at: now)
        if rest.isRunning(at: now) {
            restAlert.schedule(after: RestTimer.alertAfter)
        } else {
            restAlert.cancel()
        }
    }

    /// «Terminar» en el reloj: pregunta antes (decisión del usuario, 2026-10-31).
    public func requestFinish() {
        guard phase == .recording else { return }
        isFinishPromptPresented = true
    }

    /// «Terminar» en la alerta.
    public func confirmFinish() async {
        isFinishPromptPresented = false
        await finish()
    }

    public func cancelFinish() {
        isFinishPromptPresented = false
    }

    /// Lo confirmado en el reloj, o el entreno terminado en el iPhone (sin preguntar): deja de
    /// medir, lo guarda en Salud y enseña el resumen. En el iPhone el entreno sigue abierto hasta
    /// terminarlo allí.
    public func finish() async {
        isFinishPromptPresented = false
        guard phase == .recording else { return }
        phase = .ending
        restAlert.cancel()
        rest = RestTimer()
        if let summary = try? await recorder.end() {
            phase = .summary(Summary(summary))
        } else {
            phase = .idle
        }
    }

    /// «Listo» en el resumen.
    public func dismissSummary() {
        guard case .summary = phase else { return }
        phase = .idle
        tab = .workout
    }
}
