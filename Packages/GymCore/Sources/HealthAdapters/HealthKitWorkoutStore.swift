#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import Application
import Domain
import Foundation
import HealthKit

/// Los entrenos de Gym en Salud: los que guardó el reloj, por el día de la sesión con el que los
/// marca (`GymWorkoutMetadata`). Los de antes de marcarlos (2026-10-30) no se encuentran. HealthKit
/// solo deja borrar lo que guardó la propia app: el iPhone los busca y el reloj los borra
/// (`WatchConnectivityWorkoutDeleter`), porque ios-signer instala las dos como apps distintas.
public struct HealthKitWorkoutStore: HealthWorkoutStore {
    public init() {}

    public func hasWorkouts(on day: LocalDate) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let store = HKHealthStore()
        do {
            try await Self.authorize(store)
            return try await !Self.workouts(on: day, in: store).isEmpty
        } catch {
            return false
        }
    }

    public func deleteWorkouts(on day: LocalDate) async throws {
        _ = try await deleteAll(on: day)
    }

    /// Borra los entrenos de ese día y dice cuántos ha encontrado: sin permiso para leerlos, Salud
    /// no enseña ninguno y no da error. No pide permiso: en el reloj llega en segundo plano, donde
    /// la hoja no puede salir y la petición se quedaba esperando (`requestAccess`, con la app
    /// delante).
    public func deleteAll(on day: LocalDate) async throws -> Int {
        let store = HKHealthStore()
        let workouts = try await Self.workouts(on: day, in: store)
        for workout in workouts {
            // Lo medido no se va con el entreno: se busca antes y se borra después, si se puede.
            // Primero el entreno, que es lo que se ve en Fitness: si lo medido falla, no lo para.
            let samples = await Self.samples(of: workout, in: store)
            try await store.delete(workout)
            if !samples.isEmpty { try? await store.delete(samples) }
        }
        return workouts.count
    }

    /// Pide los permisos para buscar y borrar; la hoja del sistema sale solo si falta alguno. Con
    /// la app delante.
    public func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await Self.authorize(HKHealthStore())
    }

    private static func authorize(_ store: HKHealthStore) async throws {
        try await store.requestAuthorization(toShare: GymHealthTypes.all, read: GymHealthTypes.all)
    }

    private static func samples(of workout: HKWorkout, in store: HKHealthStore) async -> [HKQuantitySample] {
        var samples: [HKQuantitySample] = []
        for type in GymHealthTypes.measured {
            let predicate = HKQuery.predicateForObjects(from: workout)
            let found = try? await HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                           sortDescriptors: []).result(for: store)
            samples += found ?? []
        }
        return samples
    }

    private static func workouts(on day: LocalDate, in store: HKHealthStore) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: GymWorkoutMetadata.sessionDay, allowedValues: [day.iso])
        return try await HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: []).result(for: store)
    }
}
#endif
