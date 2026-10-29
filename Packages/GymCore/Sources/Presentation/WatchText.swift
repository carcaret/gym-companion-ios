import Domain

/// Los textos del reloj.
public enum WatchText {
    public static let waiting = "Abre Gym en el iPhone"
    public static let noWorkout = "Sin entreno en curso"
    public static let firstTime = "Primera vez"
    public static let skipped = "Saltado"

    /// "12·12·11·10": las reps de cada serie, aunque se repitan; una serie sin reps, "—".
    public static func reps(_ reps: [Int?]) -> String {
        LogText.reps(reps)
    }

    /// "62,5 kg", o "Peso corporal" sin peso.
    public static func weight(_ weight: Double) -> String {
        weight > 0 ? LogText.weight(weight) : "Peso corporal"
    }

    /// "21 oct".
    public static func date(_ date: LocalDate) -> String {
        DateText.dayMonth(date)
    }

    /// "2/6": la posición `index` (desde 0) de `count`.
    public static func position(_ index: Int, of count: Int) -> String {
        "\(index + 1)/\(count)"
    }
}
