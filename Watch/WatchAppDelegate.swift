import HealthKit
import WatchKit

/// El delegado de la app del reloj: tiene la raíz de composición y recibe el entreno cuando el
/// iPhone abre la app para que lo mida (`startWatchApp`, al empezar allí).
@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let root = WatchCompositionRoot()

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { await root.model.start() }
    }
}
