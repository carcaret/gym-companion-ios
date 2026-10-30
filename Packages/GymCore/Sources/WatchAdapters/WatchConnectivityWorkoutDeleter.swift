#if canImport(WatchConnectivity) && os(iOS)
import Application
import Domain

/// Los entrenos de Gym en Salud, desde el iPhone: los busca él (`finder`, HealthKit) y los borra
/// el reloj, que es quien los guardó. Salud solo deja borrar lo que guardó la propia app, y
/// ios-signer instala la del reloj como otra app (2026-10-30: desde el iPhone no se podía).
public struct WatchConnectivityWorkoutDeleter: HealthWorkoutStore {
    private let finder: any HealthWorkoutStore
    private let publisher: WatchConnectivityPublisher

    public init(finder: any HealthWorkoutStore, publisher: WatchConnectivityPublisher) {
        self.finder = finder
        self.publisher = publisher
    }

    public func hasWorkouts(on day: LocalDate) async -> Bool {
        await finder.hasWorkouts(on: day)
    }

    /// Lo borra el reloj cuando le llega la petición: si no está a tiro, al volver.
    public func deleteWorkouts(on day: LocalDate) async throws {
        try publisher.requestWorkoutDeletion(on: day)
    }
}
#endif
