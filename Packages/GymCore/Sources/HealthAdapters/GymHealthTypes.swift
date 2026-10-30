#if canImport(HealthKit)
import HealthKit

/// Lo que Gym guarda en Salud con cada entreno: el entreno y lo medido en él. El reloj pide
/// permiso para guardarlo y leerlo, y así también puede borrarlo después (`HealthKitWorkoutStore`).
enum GymHealthTypes {
    static var measured: [HKQuantityType] {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned)]
    }

    static var all: Set<HKSampleType> {
        Set([HKObjectType.workoutType()] + measured)
    }
}
#endif
