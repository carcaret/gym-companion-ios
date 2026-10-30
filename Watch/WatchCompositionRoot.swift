import Adapters
import Application
import Domain
import Foundation
import HealthAdapters
import ViewModels
import WatchAdapters

/// Raíz de composición del reloj: el único sitio de la app del reloj que conoce los adaptadores
/// concretos. Con `-demo` (o `-demo-sin-entreno`) enseña datos de ejemplo, mide un entreno de
/// mentira y no escucha al iPhone (solo para las capturas del CI).
@MainActor
final class WatchCompositionRoot {
    let model: WatchModel
    private let demo: WatchSnapshot?
    private let receiver = WatchConnectivityReceiver()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let clock = SystemClock()
        demo = WatchDemo.snapshot(arguments: arguments, today: clock.today())
        model = demo == nil
            ? WatchModel(clock: clock, recorder: HealthKitWorkoutRecorder(), restAlert: WatchKitRestAlert())
            : WatchModel(clock: clock, recorder: DemoWorkoutRecorder(), restAlert: DemoRestAlert())
    }

    /// Lo que llega del iPhone, mientras la app esté abierta. En la demo, el entreno ya empezado.
    func listen() async {
        if let demo {
            await model.receive(demo)
            if demo.workout != nil { await model.start() }
            return
        }
        receiver.start()
        for await snapshot in receiver.snapshots {
            await model.receive(snapshot)
        }
    }
}
