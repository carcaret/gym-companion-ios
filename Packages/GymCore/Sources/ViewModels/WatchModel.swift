import Application
import Domain
import Observation
import Presentation

/// La app del reloj: la app de entreno. Con el entreno en curso que llega del iPhone (`receive`),
/// mide la sesión en Salud (`WorkoutRecorder`) y enseña el tiempo, el descanso y el ejercicio que
/// se elige con la corona. El reloj no hace nada por su cuenta: ni avanza de ejercicio ni sigue lo
/// que se apunta en el iPhone. Un entreno de otro día ya no está en curso. Sin entreno, enseña las
/// rutinas: elegir una y «Empezar» mide en seguida y pide al iPhone que la empiece. Empezar o
/// terminar en uno de los dos lo hace en el otro.
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
    /// La rutina elegida en la lista, la de la pantalla de «Empezar».
    public private(set) var chosenRoutine: RoutineID?
    /// La alerta de sustituir el entreno de hoy, ya terminado.
    public private(set) var replacePrompt: ReplacePrompt?
    public private(set) var metrics = Metrics(WorkoutMetrics())

    private var phase: Phase = .idle
    /// Hasta recibir algo del iPhone.
    private var waiting = true
    /// Qué entreno se ve: si cambia, se vuelve al primer ejercicio.
    private var shownWorkout: WorkoutKey?
    private var startError: String?
    private var rest = RestTimer()
    /// Sin entreno en curso, las rutinas para empezarlo aquí.
    private var startable: WatchSnapshot.Start?
    /// El día del entreno empezado aquí, mientras no llegue del iPhone: lo que llega sin entreno
    /// es de antes de pedírselo y no lo termina.
    private var startedHere: LocalDate?

    private let clock: any Clock
    private let recorder: any WorkoutRecorder
    private let restAlert: any RestAlert
    /// Pide al iPhone que termine el entreno terminado aquí. `nil` sin iPhone (la demo).
    private let phone: (any PhoneWorkoutFinisher)?
    /// Pide al iPhone que empiece el entreno empezado aquí. `nil` sin iPhone (la demo).
    private let phoneStarter: (any PhoneWorkoutStarter)?

    public init(
        clock: any Clock, recorder: any WorkoutRecorder, restAlert: any RestAlert,
        phone: (any PhoneWorkoutFinisher)? = nil, phoneStarter: (any PhoneWorkoutStarter)? = nil
    ) {
        self.clock = clock
        self.recorder = recorder
        self.restAlert = restAlert
        self.phone = phone
        self.phoneStarter = phoneStarter
        recorder.onMetrics = { [weak self] in self?.metrics = Metrics($0) }
    }

    public var screen: Screen {
        switch phase {
        case .recording, .ending:
            return .workout
        case .summary(let summary):
            return .summary(summary)
        case .idle, .starting:
            if let shownWorkout {
                return .ready(Ready(routine: shownWorkout.routineName, detail: WatchText.exerciseCount(exercises.count),
                                    error: startError, isStarting: phase == .starting))
            }
            if waiting { return .message(WatchText.waiting) }
            let routines = routineRows
            return routines.isEmpty ? .message(WatchText.noWorkout) : .routines(routines)
        }
    }

    /// Las rutinas que se pueden empezar aquí, con el color de cada una; las que no tienen
    /// ejercicios, no (no hay nada que medir).
    private var routineRows: [RoutineRow] {
        guard let routines = startable?.routines else { return [] }
        return routines.filter { !$0.plan.exercises.isEmpty }.map { routine in
            RoutineRow(id: routine.id, name: routine.plan.routineName, tint: tint(of: routine.id))
        }
    }

    /// El de la rutina entre todas las del iPhone (también las que no salen), como en el iPhone.
    private func tint(of routine: RoutineID) -> RoutineTint? {
        RoutineTint.of(routine, in: startable?.routines.map(\.id) ?? [])
    }

    /// La pantalla de «Empezar» de la rutina elegida: su nombre y sus ejercicios.
    public var chosen: Ready? {
        guard let routine = chosenPlan else { return nil }
        return Ready(routine: routine.plan.routineName, detail: WatchText.exerciseNames(routine.plan.exercises.map(\.name)),
                     error: startError, isStarting: phase == .starting, tint: tint(of: routine.id))
    }

    private var chosenPlan: WatchSnapshot.Routine? {
        guard let chosenRoutine else { return nil }
        return startable?.routines.first { $0.id == chosenRoutine }
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

    /// Lo último del iPhone. Si se estaba midiendo y el entreno ha terminado allí, se termina aquí;
    /// salvo si se empezó aquí y aún no ha llegado allí.
    public func receive(_ snapshot: WatchSnapshot) async {
        waiting = false
        startable = snapshot.start
        if chosenRoutine != nil, chosenPlan == nil { closeChosen() }
        let today = clock.today()
        guard let workout = snapshot.workout, workout.date == today else {
            if startedHere == today, phase == .recording { return }
            let hadWorkout = shownWorkout != nil
            shownWorkout = nil
            exercises = []
            exerciseIndex = 0
            if hadWorkout { await finish() }
            return
        }
        // Con un entreno en curso (empezado aquí o allí), ya no se elige rutina.
        startedHere = nil
        closeChosen()
        show(workout)
    }

    private func show(_ workout: WatchSnapshot.Workout) {
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
                planReps: WatchText.planReps(exercise),
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

    /// Tocar una rutina de la lista: su pantalla de «Empezar».
    public func choose(_ routine: RoutineID) {
        guard startable?.routines.contains(where: { $0.id == routine }) == true else { return }
        startError = nil
        chosenRoutine = routine
    }

    /// Volver de la pantalla de «Empezar» a la lista.
    public func closeChosen() {
        chosenRoutine = nil
        replacePrompt = nil
    }

    /// «Empezar» en la pantalla de la rutina elegida: si hoy ya hay un entreno terminado, antes
    /// pregunta (empezar otro lo sustituye), como en el iPhone.
    public func requestStartChosen() async {
        guard let routine = chosenPlan else { return }
        if let done = startable?.completedRoutineName, startable?.date == clock.today() {
            replacePrompt = ReplacePrompt(title: TodayText.replaceTitle(done), message: TodayText.replaceMessage(routine.plan.routineName))
            return
        }
        await startChosen()
    }

    /// «Sustituir». Recibe el aviso como en el iPhone: SwiftUI cierra la alerta antes de la acción.
    public func confirmReplace(_ prompt: ReplacePrompt) async {
        replacePrompt = nil
        await startChosen()
    }

    public func cancelReplace() {
        replacePrompt = nil
    }

    /// Mide en seguida, con lo que el iPhone creará, y le pide que empiece el entreno. Si mientras
    /// arrancaba ha llegado un entreno del iPhone, se queda ese: manda el iPhone.
    private func startChosen() async {
        guard let routine = chosenPlan else { return }
        let today = clock.today()
        guard await beginRecording(), shownWorkout == nil else { return }
        closeChosen()
        startedHere = today
        show(WatchSnapshot.Workout(date: today, routineName: routine.plan.routineName, exercises: routine.plan.exercises))
        phoneStarter?.requestStart(PhoneWorkoutStart(routine: routine.id, day: today))
    }

    /// «Empezar» con el entreno ya en curso en el iPhone, o el iPhone que abre la app para el
    /// entreno.
    public func start() async {
        await beginRecording()
    }

    /// Empieza a medir; devuelve si ha podido.
    @discardableResult
    private func beginRecording() async -> Bool {
        switch phase {
        case .idle, .summary: break
        case .starting, .recording, .ending: return false
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
            return false
        }
        rest = RestTimer()
        tab = .workout
        phase = .recording
        return true
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

    /// «Terminar» en la alerta: termina aquí y pide al iPhone que lo termine allí, sin preguntar
    /// (decisión del usuario, 2026-10-31).
    public func confirmFinish() async {
        isFinishPromptPresented = false
        guard phase == .recording else { return }
        if let day = shownWorkout?.date { phone?.requestFinish(on: day) }
        await finish()
    }

    public func cancelFinish() {
        isFinishPromptPresented = false
    }

    /// Lo confirmado en el reloj, o el entreno terminado en el iPhone (sin preguntar): deja de
    /// medir, lo guarda en Salud y enseña el resumen.
    public func finish() async {
        isFinishPromptPresented = false
        guard phase == .recording else { return }
        phase = .ending
        startedHere = nil
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
