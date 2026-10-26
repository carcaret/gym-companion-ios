import Domain

/// Mantiene el reloj al día: con cada cambio de los datos (o del día) le envía lo que enseña, solo
/// si ha cambiado.
@MainActor
public final class WatchRelay {
    private let publisher: any WatchPublisher
    private let clock: any Clock
    private var lastSent: WatchSnapshot?

    public init(publisher: any WatchPublisher, clock: any Clock) {
        self.publisher = publisher
        self.clock = clock
    }

    /// `nil` = datos aún sin cargar: el reloj se queda con lo último que recibió.
    public func send(_ data: TrainingData?) {
        guard let data else { return }
        let snapshot = data.watchSnapshot(today: clock.today())
        guard snapshot != lastSent else { return }
        lastSent = snapshot
        publisher.publish(snapshot)
    }
}
