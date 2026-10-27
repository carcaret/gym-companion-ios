import Domain

/// Lo que dice VoiceOver en la tarjeta de un ejercicio (2026-10-27): el nombre de cada parámetro,
/// qué sube o baja cada botón y cómo va cada serie. Lo que se ve son iconos y números.
public enum CardAccessibilityText {
    public static func name(_ parameter: LogParameter) -> String {
        switch parameter {
        case .weight: "Peso"
        case .series: "Series"
        case .targetReps: "Repeticiones objetivo"
        }
    }

    public static func increase(_ parameter: LogParameter) -> String { "Subir \(name(parameter).lowercased())" }
    public static func decrease(_ parameter: LogParameter) -> String { "Bajar \(name(parameter).lowercased())" }

    public static func value(_ text: String, hasError: Bool) -> String {
        hasError ? "\(text), con error" : text
    }

    public static func seriesLabel(_ index: Int) -> String { "Serie \(index + 1)" }

    public static func seriesValue(_ reps: Int?, target: Int, hasError: Bool) -> String {
        let text = reps.map { reps in
            let count = reps == 1 ? "1 repetición" : "\(reps) repeticiones"
            return "\(count), \(reps >= target ? "objetivo cumplido" : "por debajo del objetivo")"
        } ?? "Sin completar"
        return value(text, hasError: hasError)
    }
}
