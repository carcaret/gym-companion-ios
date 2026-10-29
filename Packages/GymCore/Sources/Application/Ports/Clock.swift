import Domain

/// Puerto del reloj: el dominio nunca pregunta la fecha por su cuenta, la recibe.
public protocol Clock: Sendable {
    /// El día de hoy en la zona horaria del usuario.
    func today() -> LocalDate
}
