#if canImport(WatchConnectivity) && os(watchOS)
import Application
import Domain

/// En el reloj: pide al iPhone que termine el entreno de un día (`PhoneRequest`). Si llega dos
/// veces, la segunda no hace nada: el entreno ya está terminado.
public struct WatchConnectivityWorkoutFinisher: PhoneWorkoutFinisher {
    public init() {}

    public func requestFinish(on day: LocalDate) {
        PhoneRequest.send([WatchContext.finishWorkoutKey: day.iso], name: "Terminar \(day.iso)")
    }
}
#endif
