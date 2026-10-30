import Domain

/// Puerto: los entrenos de Gym guardados en Salud (los guarda el reloj al terminar, marcados con
/// el día de la sesión). Solo se ven y se borran los que guardó Gym, nunca los de otras apps.
public protocol HealthWorkoutStore: Sendable {
    /// Si hay algún entreno de Gym en Salud del día `day`. La primera vez pide permiso; sin él,
    /// `false`.
    func hasWorkouts(on day: LocalDate) async -> Bool
    /// Borra de Salud los entrenos de Gym de ese día y lo que se midió en ellos (las kcal y el
    /// pulso), para que Fitness deje de contarlos.
    func deleteWorkouts(on day: LocalDate) async throws
}
