#if canImport(WatchConnectivity) && os(watchOS)
import WatchConnectivity

/// En el reloj: una petición al iPhone. Con el iPhone a tiro, por `sendMessage`, que despierta la
/// app del iPhone aunque esté en segundo plano; si no, o si falla, por `transferUserInfo`, que
/// espera hasta que el iPhone la recibe. Si llegan las dos, la segunda no hace nada allí.
enum PhoneRequest {
    /// `name` dice en el registro qué se pide ("Terminar 2026-10-30").
    static func send(_ request: [String: Any], name: String) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else {
            HealthLog.logger.error("\(name, privacy: .public): la sesión con el iPhone no está activa")
            return
        }
        guard session.isReachable else {
            session.transferUserInfo(request)
            HealthLog.logger.notice("\(name, privacy: .public): el iPhone no está a tiro, en cola")
            return
        }
        session.sendMessage(request, replyHandler: nil) { error in
            HealthLog.logger.error("\(name, privacy: .public): \(String(describing: error), privacy: .public); en cola")
            WCSession.default.transferUserInfo(request)
        }
        HealthLog.logger.notice("\(name, privacy: .public): pedido al iPhone")
    }
}
#endif
