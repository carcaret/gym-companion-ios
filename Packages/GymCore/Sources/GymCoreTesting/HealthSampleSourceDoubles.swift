import Application
import Domain
import Synchronization

/// Doble de Salud: unas medidas fijas, que se pueden cambiar, o un fallo.
public final class InMemoryHealthSampleSource: HealthSampleSource {
    private struct State {
        var samples: [HealthSample]
        var failure: HealthReadError?
        var reads = 0
    }

    private let state: Mutex<State>

    public init(_ samples: [HealthSample] = []) {
        state = Mutex(State(samples: samples))
    }

    /// Las medidas que hay en Salud.
    public var samples: [HealthSample] {
        get { state.withLock { $0.samples } }
        set { state.withLock { $0.samples = newValue } }
    }

    /// Las veces que se ha leído.
    public var reads: Int { state.withLock { $0.reads } }

    /// Las siguientes lecturas fallan (`nil` = funcionan).
    public func fail(_ failure: HealthReadError?) {
        state.withLock { $0.failure = failure }
    }

    public func samples() async throws(HealthReadError) -> [HealthSample] {
        let (samples, failure) = state.withLock { state in
            state.reads += 1
            return (state.samples, state.failure)
        }
        if let failure { throw failure }
        return samples
    }
}
