import Application
import Domain
import Synchronization

/// Doble de pedir al iPhone que empiece el entreno: guarda lo pedido.
public final class RecordingPhoneWorkoutStarter: PhoneWorkoutStarter {
    private let started = Mutex<[PhoneWorkoutStart]>([])

    public init() {}

    public var requests: [PhoneWorkoutStart] { started.withLock { $0 } }

    public func requestStart(_ request: PhoneWorkoutStart) {
        started.withLock { $0.append(request) }
    }
}
