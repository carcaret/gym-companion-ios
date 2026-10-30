import Application
import Domain
import Synchronization

/// Doble de los entrenos de Gym en Salud: los días con entreno y los que se borran.
public final class InMemoryHealthWorkoutStore: HealthWorkoutStore {
    public struct Failure: Error {}

    private struct State {
        var days: Set<LocalDate>
        var deleted: [LocalDate] = []
        var failsToDelete = false
    }

    private let state: Mutex<State>

    public init(days: Set<LocalDate> = []) {
        state = Mutex(State(days: days))
    }

    /// Los días que se han pedido borrar, en orden.
    public var deleted: [LocalDate] { state.withLock { $0.deleted } }

    /// Salud no deja borrar (p. ej. sin permiso).
    public func failDeletes() {
        state.withLock { $0.failsToDelete = true }
    }

    public func hasWorkouts(on day: LocalDate) async -> Bool {
        state.withLock { $0.days.contains(day) }
    }

    public func deleteWorkouts(on day: LocalDate) async throws {
        try state.withLock {
            $0.deleted.append(day)
            if $0.failsToDelete { throw Failure() }
            $0.days.remove(day)
        }
    }
}
