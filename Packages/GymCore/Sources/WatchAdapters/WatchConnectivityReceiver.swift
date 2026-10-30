#if canImport(WatchConnectivity) && os(watchOS)
import Adapters
import Domain
import Foundation
import WatchConnectivity

/// En el reloj: lo que envía el iPhone. Al arrancar, lo último que llegó (WatchConnectivity lo
/// guarda aunque el iPhone no esté a tiro); después, cada cosa nueva. Aparte, los días cuyo
/// entreno hay que borrar de Salud, que llegan uno a uno.
public final class WatchConnectivityReceiver: NSObject, WCSessionDelegate, Sendable {
    public let snapshots: AsyncStream<WatchSnapshot>
    private let continuation: AsyncStream<WatchSnapshot>.Continuation
    public let workoutDeletions: AsyncStream<LocalDate>
    private let deletionContinuation: AsyncStream<LocalDate>.Continuation

    override public init() {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        (workoutDeletions, deletionContinuation) = AsyncStream.makeStream()
        super.init()
    }

    /// Si WatchConnectivity aún tiene algo por entregar (al despertar la app en segundo plano).
    public var hasContentPending: Bool {
        WCSession.isSupported() && WCSession.default.hasContentPending
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

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let iso = userInfo[WatchContext.deleteWorkoutsKey] as? String, let day = LocalDate(iso: iso) else { return }
        deletionContinuation.yield(day)
    }

    /// Lo que no se puede leer (p. ej. de una versión más nueva de la app del iPhone) se ignora.
    private func deliver(_ context: [String: Any]) {
        guard let data = context[WatchContext.snapshotKey] as? Data,
              let snapshot = try? WatchSnapshotCoding.decode(data) else { return }
        continuation.yield(snapshot)
    }
}
#endif
