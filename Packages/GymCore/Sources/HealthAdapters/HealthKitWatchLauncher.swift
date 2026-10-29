#if canImport(HealthKit) && os(iOS)
import Application
import HealthKit

/// Abre la app del reloj desde el iPhone para que mida el entreno (`startWatchApp`): el reloj la
/// recibe en `handle(_:)` de su delegado. Si no hay reloj o no está a tiro, no pasa nada.
public struct HealthKitWatchLauncher: WatchWorkoutLauncher {
    public init() {}

    public func launch() async {
        let store = HKHealthStore()
        await withCheckedContinuation { continuation in
            store.startWatchApp(with: .strengthTraining) { _, _ in
                continuation.resume()
            }
        }
    }
}
#endif
