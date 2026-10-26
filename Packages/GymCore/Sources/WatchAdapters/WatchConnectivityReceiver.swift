#if canImport(WatchConnectivity) && os(watchOS)
import Adapters
import Domain
import Foundation
import WatchConnectivity

/// En el reloj: lo que envía el iPhone. Al arrancar, lo último que llegó (WatchConnectivity lo
/// guarda aunque el iPhone no esté a tiro); después, cada cosa nueva.
public final class WatchConnectivityReceiver: NSObject, WCSessionDelegate, Sendable {
    public let snapshots: AsyncStream<WatchSnapshot>
    private let continuation: AsyncStream<WatchSnapshot>.Continuation

    override public init() {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    public func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        deliver(session.receivedApplicationContext)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        deliver(context)
    }

    /// Lo que no se puede leer (p. ej. de una versión más nueva de la app del iPhone) se ignora.
    private func deliver(_ context: [String: Any]) {
        guard let data = context[WatchContext.snapshotKey] as? Data,
              let snapshot = try? WatchSnapshotCoding.decode(data) else { return }
        continuation.yield(snapshot)
    }
}
#endif
