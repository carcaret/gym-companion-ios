import Application
import Synchronization

/// Doble de abrir el reloj desde el iPhone: cuenta las veces.
public final class RecordingWatchWorkoutLauncher: WatchWorkoutLauncher {
    private let count = Mutex(0)

    public init() {}

    public var launches: Int { count.withLock { $0 } }

    public func launch() async {
        count.withLock { $0 += 1 }
    }
}
