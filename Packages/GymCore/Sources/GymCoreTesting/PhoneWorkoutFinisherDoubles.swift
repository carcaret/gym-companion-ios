import Application
import Domain
import Synchronization

/// Doble de pedir al iPhone que termine el entreno: guarda los días pedidos.
public final class RecordingPhoneWorkoutFinisher: PhoneWorkoutFinisher {
    private let days = Mutex<[LocalDate]>([])

    public init() {}

    public var requests: [LocalDate] { days.withLock { $0 } }

    public func requestFinish(on day: LocalDate) {
        days.withLock { $0.append(day) }
    }
}
