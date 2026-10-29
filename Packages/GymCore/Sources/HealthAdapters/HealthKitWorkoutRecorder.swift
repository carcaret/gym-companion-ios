#if canImport(HealthKit) && os(watchOS)
import Application
import Domain
import Foundation
import HealthKit

/// La sesión de entreno del reloj con HealthKit: una `HKWorkoutSession` de fuerza tradicional con
/// su `HKLiveWorkoutBuilder`, que mide el pulso y las kcal y guarda el entreno en Salud al
/// terminar. Mientras dura, watchOS deja la app en primer plano y viva con la pantalla apagada.
///
/// Se usan las variantes con bloque de HealthKit: se llaman desde el actor principal, donde viven
/// la sesión y el builder, sin que salgan de él.
@MainActor
public final class HealthKitWorkoutRecorder: NSObject, WorkoutRecorder {
    public var onMetrics: (@MainActor (WorkoutMetrics) -> Void)?
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// HealthKit dice que no sin decir por qué, o no hay sesión que terminar.
    struct Failure: Error {}

    override public init() {
        super.init()
    }

    public func start() async throws {
        try await completion { done in
            store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: Self.measured) { success, error in done(success, error) }
        }
        let configuration = HKWorkoutConfiguration.strengthTraining
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
        builder.delegate = self
        let date = Date()
        session.startActivity(with: date)
        try await completion { done in
            builder.beginCollection(withStart: date) { success, error in done(success, error) }
        }
        self.session = session
        self.builder = builder
    }

    public func elapsed() -> Duration {
        guard let builder else { return .zero }
        return .milliseconds(Int64(builder.elapsedTime(at: Date()) * 1000))
    }

    public func end() async throws -> WorkoutSummary {
        guard let session, let builder else { throw Failure() }
        self.session = nil
        self.builder = nil
        let date = Date()
        session.end()
        try await completion { done in
            builder.endCollection(withEnd: date) { success, error in done(success, error) }
        }
        let duration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TimeInterval?, any Error>) in
            builder.finishWorkout { workout, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: workout?.duration) }
            }
        }
        let active = Self.energy(builder, .activeEnergyBurned)
        return WorkoutSummary(
            duration: .milliseconds(Int64((duration ?? builder.elapsedTime(at: date)) * 1000)),
            activeEnergy: active,
            totalEnergy: active + Self.energy(builder, .basalEnergyBurned),
            averageHeartRate: builder.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: Self.beatsPerMinute)
        )
    }

    /// Lo que se lee de Salud mientras se mide.
    private static var measured: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned)]
    }

    nonisolated private static var beatsPerMinute: HKUnit {
        .count().unitDivided(by: .minute())
    }

    nonisolated private static func energy(_ builder: HKWorkoutBuilder, _ type: HKQuantityTypeIdentifier) -> Double {
        builder.statistics(for: HKQuantityType(type))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    nonisolated private static func metrics(of builder: HKLiveWorkoutBuilder) -> WorkoutMetrics {
        let active = energy(builder, .activeEnergyBurned)
        return WorkoutMetrics(
            heartRate: builder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?.doubleValue(for: beatsPerMinute),
            activeEnergy: active,
            totalEnergy: active + energy(builder, .basalEnergyBurned)
        )
    }

    /// Espera a un bloque `(Bool, Error?)` de HealthKit.
    private func completion(_ call: (@escaping @Sendable (Bool, (any Error)?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            call { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Failure())
                }
            }
        }
    }
}

extension HealthKitWorkoutRecorder: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let metrics = Self.metrics(of: workoutBuilder)
        Task { @MainActor in
            self.onMetrics?(metrics)
        }
    }

    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#endif
