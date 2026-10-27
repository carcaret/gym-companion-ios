import Domain

/// Resúmenes de lo hecho con un ejercicio.
public enum LogText {
    /// "60 kg · 3×10 · 10·10·8": el peso si lo hay, series × objetivo y, si alguna serie no fue al
    /// objetivo, las reps de cada serie.
    public static func summary(_ log: ExerciseLog) -> String {
        var parts: [String] = []
        if log.weight > 0 { parts.append("\(kilograms(log.weight)) kg") }
        parts.append("\(log.series)×\(log.targetReps)")
        if let detail = repsDetail(log.actualReps, series: log.series, target: log.targetReps) { parts.append(detail) }
        return parts.joined(separator: " · ")
    }

    /// Las reps de cada serie ("10·8·10"), o `nil` si no hay ninguna rellenada o todas las series
    /// fueron justo al objetivo. (`formatRepsInteligente`.)
    public static func repsDetail(_ actual: [Int?], series: Int, target: Int) -> String? {
        let filled = actual.compactMap { $0 }
        guard !filled.isEmpty else { return nil }
        if filled.count == series && filled.allSatisfy({ $0 == target }) { return nil }
        return reps(actual)
    }

    /// "10·8·10", y la serie vacía, "—": en todas partes igual (2026-10-27; la PWA separaba con
    /// "-", que con una serie vacía daba "10---8").
    public static func reps(_ reps: [Int?]) -> String {
        reps.map { $0.map(String.init) ?? TodayText.emptyRep }.joined(separator: "·")
    }

    /// Kilos con coma decimal y sin ceros de sobra, a 0,01 kg: "60", "52,5", "18,25".
    public static func kilograms(_ weight: Double) -> String {
        let hundredths = Int((abs(weight) * 100).rounded())
        let sign = weight < 0 && hundredths > 0 ? "-" : ""
        var fraction = String(hundredths % 100)
        if fraction.count == 1 { fraction = "0" + fraction }
        while fraction.hasSuffix("0") { fraction.removeLast() }
        return sign + String(hundredths / 100) + (fraction.isEmpty ? "" : "," + fraction)
    }
}
