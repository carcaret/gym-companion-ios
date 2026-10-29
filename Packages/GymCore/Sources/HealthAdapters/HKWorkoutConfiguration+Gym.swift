#if canImport(HealthKit)
import HealthKit

extension HKWorkoutConfiguration {
    /// El entreno de Gym: fuerza tradicional, bajo techo. Lo mismo al abrir el reloj desde el
    /// iPhone que al medir en el reloj.
    static var strengthTraining: HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        return configuration
    }
}
#endif
