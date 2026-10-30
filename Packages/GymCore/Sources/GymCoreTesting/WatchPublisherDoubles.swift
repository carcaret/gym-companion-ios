import Application
import Domain
import Synchronization

/// Doble del reloj: apunta todo lo que se le envía.
public final class RecordingWatchPublisher: WatchPublisher {
    private let sent = Mutex<[WatchSnapshot]>([])

    public init() {}

    public var published: [WatchSnapshot] { sent.withLock { $0 } }

    public func publish(_ snapshot: WatchSnapshot) {
        sent.withLock { $0.append(snapshot) }
    }
}
