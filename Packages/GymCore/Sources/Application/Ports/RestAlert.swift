/// Puerto: la vibración del reloj cuando se cumple el descanso. La programa al empezar el descanso
/// para que llegue aunque la pantalla esté apagada.
@MainActor
public protocol RestAlert: AnyObject {
    /// Vibra dentro de `delay`; sustituye a la que hubiera programada.
    func schedule(after delay: Duration)
    /// Quita la que hubiera programada.
    func cancel()
}
