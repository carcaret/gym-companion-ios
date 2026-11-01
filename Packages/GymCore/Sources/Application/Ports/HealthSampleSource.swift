import Domain

/// Por qué no se pudo leer Salud.
public enum HealthReadError: Error, Hashable, Sendable {
    /// El aparato no tiene Salud (un iPad, el simulador sin datos...).
    case unavailable
    /// Salud ha dado un error al pedir permiso o al leer.
    case failed
}

/// Puerto: las medidas del cuerpo y lo comido que hay en Salud (`HealthQuantity`), todas, en su
/// unidad. La primera vez pide permiso para leerlas (con la app delante). Sin permiso, iOS no da
/// error: Salud parece vacío.
public protocol HealthSampleSource: Sendable {
    func samples() async throws(HealthReadError) -> [HealthSample]
}
