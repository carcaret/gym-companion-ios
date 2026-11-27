/// La ventana de Progreso: las series y el progreso de cada ejercicio, en las últimas 8 semanas.
public enum ProgressWindow {
    public static let weeks = 8
    /// Al abrir un ejercicio, cómo estaba hace 3 meses: cuando el avance se ralentiza, en 8 semanas
    /// parece parado y en 3 meses se ve lo que ha subido (decisión del usuario, 2026-11-27).
    public static let lookBackMonths = 3
    /// Y no más atrás: si la última sesión tan antigua es de hace más de 4 meses (un ejercicio que
    /// estuvo parado), no dice cómo estaba hace 3 y no sale (decisión del usuario, 2026-11-27).
    public static let lookBackLimitMonths = 4
}

/// Cuándo está estancado un ejercicio: hacen falta las dos condiciones. A su ritmo, no batir el
/// récord en una sesión es lo normal (con una basta, salían 12 de 20); el mínimo de sesiones evita
/// que un parón o un ejercicio saltado lo marque con una o dos (decisión del usuario, 2026-11-27).
public enum StallThreshold {
    /// Sesiones al peso actual después del récord de reps que no lo superan.
    public static let minimumSessionsWithoutRecord = 3
    /// Días desde ese récord hasta hoy.
    public static let minimumDaysWithoutRecord = 28
}
