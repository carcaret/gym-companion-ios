import HealthKit
import WatchKit

/// El delegado de la app del reloj: tiene la raíz de composición, recibe el entreno cuando el
/// iPhone abre la app para que lo mida (`startWatchApp`, al empezar allí) y, despertada en segundo
/// plano por WatchConnectivity, deja tiempo para borrar de Salud lo que pida el iPhone.
@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let root = WatchCompositionRoot()

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { await root.model.start() }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task {
                await root.finishPendingDeletions()
                connectivity.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
