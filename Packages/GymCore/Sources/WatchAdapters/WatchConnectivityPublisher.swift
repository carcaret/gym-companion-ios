#if canImport(WatchConnectivity) && os(iOS)
import Adapters
import Application
import Domain
import Foundation
import Synchronization
import WatchConnectivity

/// Envía al reloj lo que tiene que enseñar con `updateApplicationContext`: WatchConnectivity
/// guarda solo lo último y se lo entrega al reloj en cuanto está a tiro. Si la sesión aún no está
/// activa, lo envía al activarse.
public final class WatchConnectivityPublisher: NSObject, WatchPublisher, WCSessionDelegate, @unchecked Sendable {
    /// Lo último que hay que enseñar (WCSession avisa desde una cola suya).
    private let latest = Mutex<WatchSnapshot?>(nil)

    override public init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func publish(_ snapshot: WatchSnapshot) {
        latest.withLock { $0 = snapshot }
        send()
    }

    /// Pide al reloj que borre de Salud los entrenos de Gym de `day`. `transferUserInfo` guarda
    /// la petición hasta que el reloj la recibe, aunque no esté a tiro.
    func requestWorkoutDeletion(on day: LocalDate) throws {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            throw WatchUnavailable()
        }
        session.transferUserInfo([WatchContext.deleteWorkoutsKey: day.iso])
    }

    /// Sin reloj emparejado o sin la app del reloj, `updateApplicationContext` falla: no pasa
    /// nada, lo siguiente que se publique lo vuelve a intentar.
    private func send() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let snapshot = latest.withLock({ $0 }), let data = try? WatchSnapshotCoding.encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([WatchContext.snapshotKey: data])
    }

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        send()
    }

    /// Sin reloj emparejado, con la app del reloj, y con la sesión activa.
    struct WatchUnavailable: Error {}

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Al cambiar de reloj: se activa otra vez para el nuevo.
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
