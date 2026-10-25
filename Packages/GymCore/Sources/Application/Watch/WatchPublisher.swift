import Domain

/// Puerto del reloj: le hace llegar lo que tiene que enseñar. Basta con lo último; si el reloj no
/// está a tiro, lo recibe cuando vuelva.
public protocol WatchPublisher: Sendable {
    func publish(_ snapshot: WatchSnapshot)
}
