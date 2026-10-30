import Adapters
import Application
import Domain
import Foundation
import HealthAdapters
import ViewModels
import WatchAdapters

/// Raíz de composición del reloj: el único sitio de la app del reloj que conoce los adaptadores
/// concretos. Escucha al iPhone desde que arranca la app, también en segundo plano: lo que enseña
/// y los entrenos que hay que borrar de Salud (los guardó el reloj, así que solo él puede). Con
/// `-demo` (o `-demo-sin-entreno`) enseña datos de ejemplo, mide un entreno de mentira y no escucha
/// al iPhone (solo para las capturas del CI).
@MainActor
final class WatchCompositionRoot {
    let model: WatchModel
    private let demo: WatchSnapshot?
    /// Fuera de la demo: lo que envía el iPhone.
    private let receiver: WatchConnectivityReceiver?
    /// Cuántos borrados de Salud están en marcha.
    private var deleting = 0

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let clock = SystemClock()
        demo = WatchDemo.snapshot(arguments: arguments, today: clock.today())
        if demo == nil {
            model = WatchModel(clock: clock, recorder: HealthKitWorkoutRecorder(), restAlert: WatchKitRestAlert())
            let receiver = WatchConnectivityReceiver()
            self.receiver = receiver
            receiver.start()
            Task { await deleteWorkouts(from: receiver) }
        } else {
            model = WatchModel(clock: clock, recorder: DemoWorkoutRecorder(), restAlert: DemoRestAlert())
            receiver = nil
        }
    }

    /// Lo que llega del iPhone, mientras la app esté abierta. En la demo, el entreno ya empezado.
    func listen() async {
        if let demo {
            await model.receive(demo)
            if demo.workout != nil { await model.start() }
            return
        }
        guard let receiver else { return }
        for await snapshot in receiver.snapshots {
            await model.receive(snapshot)
        }
    }

    /// Al despertar en segundo plano por WatchConnectivity: espera a que llegue lo pendiente y se
    /// borre de Salud, como mucho 20 s (watchOS da poco tiempo).
    func finishPendingDeletions() async {
        guard let receiver else { return }
        let deadline = ContinuousClock.now + .seconds(20)
        while receiver.hasContentPending || deleting > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// Lo que no se puede borrar (sin permiso) se queda en Salud: el iPhone ya avisó al pedirlo
    /// si el reloj no estaba.
    private func deleteWorkouts(from receiver: WatchConnectivityReceiver) async {
        let store = HealthKitWorkoutStore()
        for await day in receiver.workoutDeletions {
            deleting += 1
            try? await store.deleteWorkouts(on: day)
            deleting -= 1
        }
    }
}
