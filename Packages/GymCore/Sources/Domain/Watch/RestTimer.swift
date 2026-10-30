/// El descanso entre series del reloj. Un toque lo empieza (cuenta desde cero); otro toque, mientras
/// cuenta, lo para y lo deja a cero. Al cumplir `alertAfter` vibra y sigue contando; al llegar a
/// `resetAfter` vuelve solo a cero. No se guarda en ningún sitio.
///
/// Se mide en tiempo del entreno (lo que lleva la sesión de Salud), no con la hora del sistema.
public struct RestTimer: Hashable, Sendable {
    /// Cuándo vibra: el descanso cumplido.
    public static let alertAfter: Duration = .seconds(90)
    /// Cuándo vuelve solo a cero.
    public static let resetAfter: Duration = .seconds(150)

    public enum State: Hashable, Sendable {
        /// A cero: no cuenta hasta el siguiente toque.
        case idle
        /// Contando, aún sin cumplir.
        case resting(Duration)
        /// Cumplido: sigue contando hasta `resetAfter`.
        case overdue(Duration)
    }

    /// En qué momento del entreno empezó, si se ha tocado.
    public private(set) var startedAt: Duration?

    public init() {}

    public func state(at now: Duration) -> State {
        guard let startedAt else { return .idle }
        let elapsed = now - startedAt
        guard elapsed >= .zero, elapsed < Self.resetAfter else { return .idle }
        return elapsed < Self.alertAfter ? .resting(elapsed) : .overdue(elapsed)
    }

    public func isRunning(at now: Duration) -> Bool {
        state(at: now) != .idle
    }

    /// A cero, empieza; contando, se para y vuelve a cero.
    public mutating func tap(at now: Duration) {
        startedAt = isRunning(at: now) ? nil : now
    }
}
