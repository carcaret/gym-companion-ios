import Application
import Domain
import Observation
import Presentation

/// La pantalla del reloj: una página por ejercicio del entreno en curso, con lo que llega del
/// iPhone (`receive`). Se pasa de una a otra con la corona; empieza en el primer ejercicio. Lo
/// recibido se guarda en el reloj: un entreno de otro día ya no está en curso.
@MainActor
@Observable
public final class WatchModel {
    public enum Content: Hashable, Sendable {
        /// Sin entreno que enseñar: el porqué.
        case message(String)
        case workout([Page])
    }

    public struct Page: Hashable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        /// "2/6".
        public let position: String
        public let weight: String
        /// Las reps de hoy, "12-12-11-10".
        public let reps: String
        /// Saltado hoy: se pinta atenuado.
        public let isSkipped: Bool
        public let previous: [PreviousRow]
        /// "Primera vez", si no hay sesiones anteriores.
        public let noPrevious: String?
    }

    public struct PreviousRow: Hashable, Sendable {
        public let date: String
        public let reps: String

        public init(date: String, reps: String) {
            self.date = date
            self.reps = reps
        }
    }

    public private(set) var content: Content = .message(WatchText.waiting)
    /// El ejercicio que se ve, por posición.
    public var page = 0
    /// Qué entreno se ve: si cambia, se vuelve al primer ejercicio.
    private var shownWorkout: WorkoutKey?

    private struct WorkoutKey: Hashable {
        let date: LocalDate
        let routineName: String
    }

    private let clock: any Clock

    public init(clock: any Clock) {
        self.clock = clock
    }

    public func receive(_ snapshot: WatchSnapshot) {
        guard let workout = snapshot.workout, workout.date == clock.today() else {
            content = .message(WatchText.noWorkout)
            shownWorkout = nil
            page = 0
            return
        }
        let key = WorkoutKey(date: workout.date, routineName: workout.routineName)
        if key != shownWorkout {
            shownWorkout = key
            page = 0
        }
        let count = workout.exercises.count
        page = min(page, max(count - 1, 0))
        content = .workout(workout.exercises.enumerated().map { index, exercise in
            Page(
                id: index,
                name: exercise.name,
                position: WatchText.position(index, of: count),
                weight: WatchText.weight(exercise.weight),
                reps: WatchText.reps(exercise.reps),
                isSkipped: exercise.skipped,
                previous: exercise.previous.map { PreviousRow(date: WatchText.date($0.date), reps: WatchText.reps($0.reps)) },
                noPrevious: exercise.previous.isEmpty ? WatchText.firstTime : nil
            )
        })
    }
}
