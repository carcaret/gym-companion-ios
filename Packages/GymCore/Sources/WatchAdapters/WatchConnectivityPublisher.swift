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

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Al cambiar de reloj: se activa otra vez para el nuevo.
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
