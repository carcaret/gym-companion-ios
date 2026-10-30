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
    public enum Screen: Hashable, Sendable {
        /// Sin entreno que enseñar: el porqué.
        case message(String)
        /// Hay entreno en el iPhone y el reloj aún no lo mide.
        case ready(Ready)
        /// Midiendo: las tres páginas (`Tab`).
        case workout
        case summary(Summary)
    }

    /// Las páginas mientras se mide, de izquierda a derecha.
    public enum Tab: Hashable, Sendable {
        case music, workout, controls
    }

    public struct Ready: Hashable, Sendable {
        public let routine: String
        /// "7 ejercicios".
        public let detail: String
        /// Por qué no se ha podido empezar la última vez.
        public let error: String?
        /// Pidiendo permiso o arrancando la sesión: el botón no se puede volver a pulsar.
        public let isStarting: Bool

        public init(routine: String, detail: String, error: String?, isStarting: Bool) {
            self.routine = routine
            self.detail = detail
            self.error = error
            self.isStarting = isStarting
        }
    }

    public struct Exercise: Hashable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        /// "2/6".
        public let position: String
        /// "62,5 kg · 4 × 11".
        public let plan: String
        /// Saltado hoy: se pinta atenuado.
        public let isSkipped: Bool
        /// "Saltado", junto al plan: no basta con que se vea más apagado.
        public let status: String?
        public let best: Reference?
        public let last: Reference?
        /// "Primera vez", si nunca se ha hecho.
        public let firstTime: String?
    }

    /// Una sesión de referencia: "Mejor 11·11·10·8 · 26 oct" o "Última 12 kg · 10·10·10 · 21 oct".
    public struct Reference: Hashable, Sendable {
        public let label: String
        public let detail: String
        public let date: String

        public init(label: String, detail: String, date: String) {
            self.label = label
            self.detail = detail
            self.date = date
        }
    }

    public enum RestPhase: Hashable, Sendable {
        case idle, resting, overdue
    }

    /// El tiempo del entreno y el descanso, en este momento.
    public struct Time: Hashable, Sendable {
        public let elapsed: String
        public let rest: String
        public let restLabel: String
        public let restPhase: RestPhase
        /// Cuánto se lleva del descanso hasta cumplirlo, de 0 a 1.
        public let restProgress: Double
    }

    public struct Metrics: Hashable, Sendable {
        public let heartRate: String
        public let activeEnergy: String
        public let totalEnergy: String

        public init(heartRate: String, activeEnergy: String, totalEnergy: String) {
            self.heartRate = heartRate
            self.activeEnergy = activeEnergy
            self.totalEnergy = totalEnergy
        }

        init(_ metrics: WorkoutMetrics) {
            self.init(heartRate: WatchText.heartRate(metrics.heartRate), activeEnergy: WatchText.energy(metrics.activeEnergy),
                      totalEnergy: WatchText.energy(metrics.totalEnergy))
        }
    }

    public struct Summary: Hashable, Sendable {
        public let duration: String
        public let activeEnergy: String
        public let totalEnergy: String
        public let averageHeartRate: String

        public init(duration: String, activeEnergy: String, totalEnergy: String, averageHeartRate: String) {
            self.duration = duration
            self.activeEnergy = activeEnergy
            self.totalEnergy = totalEnergy
            self.averageHeartRate = averageHeartRate
        }

        init(_ summary: WorkoutSummary) {
            self.init(duration: WatchText.duration(summary.duration), activeEnergy: WatchText.energy(summary.activeEnergy),
                      totalEnergy: WatchText.energy(summary.totalEnergy), averageHeartRate: WatchText.averageHeartRate(summary.averageHeartRate))
        }
    }

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
    public var exerciseIndex = 0
    public var tab: Tab = .workout
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
                plan: WatchText.plan(weight: exercise.weight, series: exercise.series, reps: exercise.targetReps),
                isSkipped: exercise.skipped,
                status: exercise.skipped ? WatchText.skipped : nil,
                best: exercise.best.map { Reference(label: WatchText.best, detail: WatchText.reps($0.reps), date: WatchText.date($0.date)) },
                last: exercise.last.map {
                    Reference(label: WatchText.last, detail: WatchText.reference(weight: $0.weight, reps: $0.reps), date: WatchText.date($0.date))
                },
                firstTime: exercise.best == nil && exercise.last == nil ? WatchText.firstTime : nil
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
            try await recorder.start()
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

    /// «Terminar» en el reloj, o el entreno terminado en el iPhone: deja de medir, lo guarda en
    /// Salud y enseña el resumen. En el iPhone el entreno sigue abierto hasta terminarlo allí.
    public func finish() async {
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
