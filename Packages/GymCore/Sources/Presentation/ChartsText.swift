import Domain

/// Los textos de la pestaña Gráficas (`views/charts.js`).
public enum ChartsText {
    public static let title = "Gráficas"
    public static let from = "Desde"
    public static let to = "Hasta"
    public static let exercise = "Ejercicio"
    public static let chooseExercise = "Elegir"
    public static let searchPlaceholder = "Buscar ejercicio..."
    public static let inRoutine = "En rutinas"
    public static let others = "Otros"
    public static let noResults = "Sin resultados"
    public static let e1rmLabel = "e1RM"
    public static let weightLabel = "Peso"
    public static let e1rmAxis = "e1RM (kg)"
    public static let weightAxis = "Peso (kg)"
    public static let empty = "Elige un ejercicio para ver su progreso"

    /// "e1RM: 84" o "e1RM: 84 · saltado (mantiene)" (el tooltip de la PWA).
    public static func pointLabel(_ series: String, value: Double, carriedForward: Bool) -> String {
        let number = value == value.rounded() ? String(Int(value)) : "\(value)"
        return "\(series): \(number)" + (carriedForward ? " · saltado (mantiene)" : "")
    }
}
