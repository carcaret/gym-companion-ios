import Application
import Domain
import Synchronization

/// Reloj parado en un día.
public struct FixedClock: Clock {
    private let day: LocalDate

    public init(_ day: LocalDate) {
        self.day = day
    }

    public func today() -> LocalDate { day }
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
