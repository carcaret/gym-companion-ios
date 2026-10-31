#if canImport(WatchConnectivity) && os(watchOS)
import Application
import Domain
import WatchConnectivity

/// En el reloj: pide al iPhone que termine el entreno de un día. Con el iPhone a tiro, por
/// `sendMessage`, que despierta la app del iPhone aunque esté en segundo plano; si no, o si falla,
/// por `transferUserInfo`, que espera hasta que el iPhone lo recibe. Si llegan los dos, el
/// segundo no hace nada: el entreno ya está terminado.
public struct WatchConnectivityWorkoutFinisher: PhoneWorkoutFinisher {
    public init() {}

    public func requestFinish(on day: LocalDate) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else {
            HealthLog.logger.error("Terminar \(day.iso, privacy: .public): la sesión con el iPhone no está activa")
            return
        }
        let request = [WatchContext.finishWorkoutKey: day.iso]
        guard session.isReachable else {
            session.transferUserInfo(request)
            HealthLog.logger.notice("Terminar \(day.iso, privacy: .public): el iPhone no está a tiro, en cola")
            return
        }
        session.sendMessage(request, replyHandler: nil) { error in
            HealthLog.logger.error("Terminar \(day.iso, privacy: .public): \(String(describing: error), privacy: .public); en cola")
            WCSession.default.transferUserInfo(request)
        }
        HealthLog.logger.notice("Terminar \(day.iso, privacy: .public): pedido al iPhone")
    }
}
#endif
