import Domain

/// Los textos de la pestaña Progreso (`views/estadisticas.js`).
public enum StatsText {
    /// Como su pestaña (la PWA: «Estadísticas»; decisión del usuario, 2026-10-27).
    public static let title = "Progreso"
    public static let exercisesTitle = "Ejercicios"
    public static let groupsTitle = "Grupos musculares"
    public static let recentSessions = "Últimas sesiones"
    public static let openCharts = "Ver en Gráficas"
    // Las etiquetas sueltas empiezan en mayúscula, como en iOS (repaso de la HIG, 2026-10-28).
    public static let direct = "Directo"
    public static let indirect = "Indirecto"
    public static let setsHeader = "series"
    public static let sessionsHeader = "· sesiones"

    public static func window(weeks: Int) -> String { "Últimas \(weeks) semanas" }

    /// "1 de 3 estancados" o, sin ninguno, "Nada estancado · 2 progresando".
    public static func exercisesSubtitle(stalled: Int, total: Int, progressing: Int) -> String {
        stalled > 0 ? "\(stalled) de \(total) \(total == 1 ? "estancado" : "estancados")" : "Nada estancado · \(progressing) progresando"
    }

    public static func referenceBand(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound) series"
    }

    /// Series indirectas con un decimal como mucho ("2,5", "3").
    public static func indirectSets(_ sets: Double) -> String {
        LogText.kilograms((sets * 10).rounded() / 10)
    }
}
