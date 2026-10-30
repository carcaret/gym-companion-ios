#if canImport(HealthKit) && os(iOS)
import Application
import Domain
import Foundation
import HealthKit

/// Los entrenos de Gym en Salud, desde el iPhone: los que guardó el reloj, por el día de la sesión
/// con el que los marca (`GymWorkoutMetadata`). Los de antes de marcarlos (2026-10-30) no se
/// encuentran. HealthKit solo deja borrar lo que guardó la app.
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
        let store = HKHealthStore()
        try await Self.authorize(store)
        for workout in try await Self.workouts(on: day, in: store) {
            // Lo medido no se va con el entreno: sin borrarlo, Fitness lo sigue contando.
            for type in Self.measured {
                let predicate = HKQuery.predicateForObjects(from: workout)
                let samples = try await HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                                sortDescriptors: []).result(for: store)
                if !samples.isEmpty { try await store.delete(samples) }
            }
            try await store.delete(workout)
        }
    }

    /// Lo que guarda el reloj con cada entreno.
    private static var measured: [HKQuantityType] {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned)]
    }

    /// Para buscar y borrar hacen falta los dos permisos; la hoja del sistema sale solo la primera vez.
    private static func authorize(_ store: HKHealthStore) async throws {
        let types: Set<HKSampleType> = Set([HKObjectType.workoutType()] + measured)
        try await store.requestAuthorization(toShare: types, read: types)
    }

    private static func workouts(on day: LocalDate, in store: HKHealthStore) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: GymWorkoutMetadata.sessionDay, allowedValues: [day.iso])
        return try await HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: []).result(for: store)
    }
}
#endif
