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
    private let clock = SystemClock()
    let model: WatchModel
    private let receiver = WatchConnectivityReceiver()

    init() {
        model = WatchModel(clock: clock)
    }

    /// Lo que llega del iPhone, mientras la app esté abierta.
    func listen() async {
        if let demo = WatchDemo.snapshot(arguments: ProcessInfo.processInfo.arguments, today: clock.today()) {
            model.receive(demo)
            return
        }
        receiver.start()
        for await snapshot in receiver.snapshots {
            model.receive(snapshot)
        }
    }
}
