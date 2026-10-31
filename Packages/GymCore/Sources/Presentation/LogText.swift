import Domain

/// Resúmenes de lo hecho con un ejercicio.
public enum LogText {
    /// "60 kg · 10·10·8": el peso si lo hay y las reps de cada serie, también cuando todas fueron
    /// al objetivo, como en el reloj (decisión del usuario, 2026-10-31; la PWA ponía «3×10» y solo
    /// las reps que no llegaban: «60 kg · 3×10 · 10·10·8»).
    public static func summary(_ log: ExerciseLog) -> String {
        var parts: [String] = []
        if log.weight > 0 { parts.append(weight(log.weight)) }
        if log.series > 0 { parts.append(reps(log.seriesReps)) }
        return parts.joined(separator: " · ")
    }

    /// La serie sin rellenar.
    public static let emptyRep = "—"

    /// "10·8·10", y la serie vacía, "—": en todas partes igual (2026-10-27; la PWA separaba con
    /// "-", que con una serie vacía daba "10---8").
    public static func reps(_ reps: [Int?]) -> String {
        reps.map { $0.map(String.init) ?? emptyRep }.joined(separator: "·")
    }

    /// "60 kg", "52,5 kg".
    public static func weight(_ kilograms: Double) -> String {
        "\(Self.kilograms(kilograms)) kg"
    }

    /// Los kilos, sin la unidad: "60", "52,5", "18,25" (`decimal`, con su nombre).
    public static func kilograms(_ weight: Double) -> String {
        decimal(weight)
    }

    /// Un número con coma decimal y sin ceros de sobra, a 0,01: "60", "52,5", "18,25".
    public static func decimal(_ value: Double) -> String {
        let hundredths = Int((abs(value) * 100).rounded())
        let sign = value < 0 && hundredths > 0 ? "-" : ""
        var fraction = String(hundredths % 100)
        if fraction.count == 1 { fraction = "0" + fraction }
        while fraction.hasSuffix("0") { fraction.removeLast() }
        return sign + String(hundredths / 100) + (fraction.isEmpty ? "" : "," + fraction)
    }
}
