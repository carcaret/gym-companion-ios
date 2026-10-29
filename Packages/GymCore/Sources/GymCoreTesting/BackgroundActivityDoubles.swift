import Application
import Domain

/// Cuenta las veces que se pidió tiempo en segundo plano y ejecuta el trabajo.
public actor RecordingBackgroundActivity: BackgroundActivity {
    public private(set) var runs = 0

    public init() {}

    public func run(_ work: @escaping @Sendable () async -> Void) async {
        runs += 1
        await work()
    }
}
