/// Intercambio recíproco pendiente: al cambiar en un día un ejercicio por otro que pertenece a
/// otra rutina, esa otra rutina hará el cambio inverso la próxima vez, si es esta misma semana.
/// Diseño: `docs/superpowers/specs/2026-07-14-swap-reciproco-design.md` de la PWA.
public struct PendingSwap: Hashable, Sendable {
    public var from: ExerciseID
    public var to: ExerciseID
    /// Lunes de la semana en que se creó; caduca al cambiar de semana.
    public var weekStart: LocalDate

    public init(from: ExerciseID, to: ExerciseID, weekStart: LocalDate) {
        self.from = from
        self.to = to
        self.weekStart = weekStart
    }
}
