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

/// Reloj que se puede adelantar (el cambio de día).
public final class SettableClock: Clock {
    private let current: Mutex<LocalDate>

    public init(_ day: LocalDate) {
        current = Mutex(day)
    }

    public var day: LocalDate {
        get { current.withLock { $0 } }
        set { current.withLock { $0 = newValue } }
    }

    public func today() -> LocalDate { day }
}
