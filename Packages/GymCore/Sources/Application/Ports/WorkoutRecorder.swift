import Domain

/// Puerto: la sesión de entreno del reloj (en Apple, una `HKWorkoutSession` de fuerza
/// tradicional). Mientras dura, mide el tiempo, el pulso y las kcal, cuenta para los anillos y
/// deja la app en primer plano; al terminar, guarda el entreno en Salud.
@MainActor
public protocol WorkoutRecorder: AnyObject {
    /// Lo que va midiendo, cada vez que cambia.
    var onMetrics: (@MainActor (WorkoutMetrics) -> Void)? { get set }
    /// Pide permiso a Salud (la primera vez enseña la hoja del sistema) y empieza a medir. El
    /// entreno se guarda marcado con `day`, el de la sesión, para encontrarlo después
    /// (`HealthWorkoutStore`).
    func start(on day: LocalDate) async throws
    /// El tiempo de entreno hasta ahora; cero si no se está midiendo.
    func elapsed() -> Duration
    /// Deja de medir y guarda el entreno en Salud.
    func end() async throws -> WorkoutSummary
}
