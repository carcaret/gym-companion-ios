import Adapters
import Domain
import Foundation
import ViewModels
import WatchAdapters

/// Raíz de composición del reloj: el único sitio de la app del reloj que conoce los adaptadores
/// concretos. Con `-demo` (o `-demo-sin-entreno`) enseña datos de ejemplo y no escucha al iPhone
/// (solo para las capturas del CI).
@MainActor
final class WatchCompositionRoot {
    let model = WatchModel(clock: SystemClock())
    private let receiver = WatchConnectivityReceiver()

    /// Lo que llega del iPhone, mientras la app esté abierta.
    func listen() async {
        if let demo = WatchDemo.snapshot(arguments: ProcessInfo.processInfo.arguments, today: SystemClock().today()) {
            model.receive(demo)
            return
        }
        receiver.start()
        for await snapshot in receiver.snapshots {
            model.receive(snapshot)
        }
    }
}
