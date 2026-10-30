#if canImport(WatchKit) && os(watchOS)
import Application
import WatchKit

/// La vibración del descanso con WatchKit. Durante la sesión de entreno la app sigue viva con la
/// pantalla apagada, así que la espera programada llega a su hora.
@MainActor
public final class WatchKitRestAlert: RestAlert {
    private var pending: Task<Void, Never>?

    public init() {}

    public func schedule(after delay: Duration) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.notification)
        }
    }

    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}
#endif
