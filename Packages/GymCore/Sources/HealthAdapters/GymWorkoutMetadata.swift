/// Con qué marca el reloj cada entreno que guarda en Salud: el día de su sesión ("2026-10-30"), para
/// que el iPhone lo encuentre al borrar la sesión. Una clave propia no puede empezar por "HK".
enum GymWorkoutMetadata {
    static let sessionDay = "GymCompanionSessionDay"
}
