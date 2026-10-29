/// Los textos de la pestaña Gráficas (`views/charts.js`).
public enum ChartsText {
    public static let title = "Gráficas"
    /// El eje de las fechas, para VoiceOver.
    public static let dateAxis = "Fecha"
    public static let from = "Desde"
    public static let to = "Hasta"
    public static let exercise = "Ejercicio"
    public static let chooseExercise = "Elegir"
    public static let inRoutine = "En rutinas"
    public static let others = "Otros"
    public static let noResults = "Sin resultados"
    public static let e1rmLabel = "e1RM"
    public static let weightLabel = "Peso"
    public static let e1rmAxis = "e1RM (kg)"
    public static let weightAxis = "Peso (kg)"
    public static let empty = "Elige un ejercicio para ver su progreso"
    public static let range = "Rango"

    /// Un atajo del rango: "1M", "1A" o, con `nil`, "Todo".
    public static func presetLabel(months: Int?) -> String {
        guard let months else { return "Todo" }
        return months % 12 == 0 ? "\(months / 12)A" : "\(months)M"
    }

    /// El mismo atajo, entero para VoiceOver: "1 mes", "3 meses", "1 año".
    public static func presetAccessibilityLabel(months: Int?) -> String {
        guard let months else { return "Todo" }
        if months % 12 == 0 { return months == 12 ? "1 año" : "\(months / 12) años" }
        return months == 1 ? "1 mes" : "\(months) meses"
    }

    /// "e1RM: 76,7 kg" o "e1RM: 76,7 kg · saltado (mantiene)" (el tooltip de la PWA): los kilos con coma decimal, como en el resto de la app (antes "76.7", sin
    /// unidad; decisión del usuario, 2026-10-27).
    public static func pointLabel(_ series: String, value: Double, carriedForward: Bool) -> String {
        "\(series): \(LogText.kilograms(value)) kg" + (carriedForward ? " · saltado (mantiene)" : "")
    }
}
