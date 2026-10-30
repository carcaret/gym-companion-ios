import Application

/// Doble de la vibración del descanso: apunta lo que se programa y se quita.
@MainActor
public final class RecordingRestAlert: RestAlert {
    public private(set) var scheduled: [Duration] = []
    public private(set) var cancellations = 0

    public init() {}

    public func schedule(after delay: Duration) {
        scheduled.append(delay)
    }

    public func cancel() {
        cancellations += 1
    }
}
