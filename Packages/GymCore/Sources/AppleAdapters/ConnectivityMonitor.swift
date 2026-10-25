#if canImport(Network)
import Foundation
import Network

/// Avisa cuando vuelve la red (el evento `online` de la PWA, que reintenta subir lo pendiente).
public enum ConnectivityMonitor {
    /// Un elemento cada vez que se pasa de no tener red a tenerla.
    public static func reconnections() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let watcher = PathWatcher()
            watcher.monitor.pathUpdateHandler = { path in
                if watcher.update(online: path.status == .satisfied) { continuation.yield() }
            }
            continuation.onTermination = { _ in watcher.monitor.cancel() }
            watcher.monitor.start(queue: DispatchQueue(label: "com.carcaret.gymcompanion.connectivity"))
        }
    }
}

/// El monitor y lo último que dijo; solo lo toca la cola del monitor (y `cancel`, que es seguro
/// desde cualquier hilo).
private final class PathWatcher: @unchecked Sendable {
    let monitor = NWPathMonitor()
    private var online: Bool?

    /// `true` si es una reconexión.
    func update(online new: Bool) -> Bool {
        defer { online = new }
        return online == false && new
    }
}
#endif
