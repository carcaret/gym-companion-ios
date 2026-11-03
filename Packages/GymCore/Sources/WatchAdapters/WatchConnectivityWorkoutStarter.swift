#if canImport(WatchConnectivity) && os(watchOS)
import Application
import Domain

/// En el reloj: pide al iPhone que empiece el entreno de una rutina, que ya se mide en el reloj
/// (`PhoneRequest`). Si llega dos veces, la segunda no hace nada: el entreno ya está en curso.
public struct WatchConnectivityWorkoutStarter: PhoneWorkoutStarter {
    public init() {}

    public func requestStart(_ request: PhoneWorkoutStart) {
        PhoneRequest.send([WatchContext.startWorkoutKey: request.day.iso, WatchContext.startRoutineKey: request.routine.rawValue],
                          name: "Empezar \(request.routine.rawValue) \(request.day.iso)")
    }
}
#endif
