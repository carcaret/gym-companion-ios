import Domain

/// Los textos del reloj.
public enum WatchText {
    public static let waiting = "Abre Gym en el iPhone"
    public static let noWorkout = "Empieza el entreno en el iPhone"
    public static let firstTime = "Primera vez"
    public static let skipped = "Saltado"
    public static let start = "Empezar"
    public static let startFailed = "No se ha podido empezar a medir. Mira los permisos de Salud en el iPhone."
    public static let best = "Mejor"
    public static let last = "Última"
    public static let total = "total"
    public static let restIdle = "toca para descansar"
    public static let resting = "descanso"
    public static let restOverdue = "a por la siguiente"
    public static let rest = "Descanso"
    public static let heartRateUnit = "PPM"
    public static let activeEnergyUnit = "KCAL ACTIVAS"
    public static let totalEnergyUnit = "KCAL TOTALES"
    public static let finish = "Terminar"
    public static let finished = "Entreno terminado"
    public static let activity = "Fuerza tradicional"
    public static let savedToHealth = "Guardado en Salud"
    public static let done = "Listo"
    public static let duration = "Tiempo"
    public static let activeEnergy = "Kcal activas"
    public static let totalEnergy = "Kcal totales"
    public static let averageHeartRate = "Pulso medio"

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

    /// "62,5 kg · 4 × 11": el plan de hoy.
    public static func plan(weight: Double, series: Int, reps: Int) -> String {
        "\(self.weight(weight)) · \(series) × \(reps)"
    }

    /// "12 kg · 10·10·10": una sesión de referencia con otro peso que el plan.
    public static func reference(weight: Double, reps: [Int?]) -> String {
        "\(self.weight(weight)) · \(self.reps(reps))"
    }

    /// "7 ejercicios".
    public static func exerciseCount(_ count: Int) -> String {
        Plural.exercises(count)
    }

    /// "23:41", o "1:02:13" a partir de una hora: el tiempo del entreno o del descanso.
    public static func duration(_ duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds))
        let hours = total / 3600, minutes = total / 60 % 60, seconds = total % 60
        return hours > 0 ? "\(hours):\(twoDigits(minutes)):\(twoDigits(seconds))" : "\(minutes):\(twoDigits(seconds))"
    }

    /// Lo que dice el descanso según en qué punto está.
    public static func restLabel(_ state: RestTimer.State) -> String {
        switch state {
        case .idle: restIdle
        case .resting: resting
        case .overdue: restOverdue
        }
    }

    /// "128", o "--" sin medida aún.
    public static func heartRate(_ beatsPerMinute: Double?) -> String {
        beatsPerMinute.map { "\(Int($0.rounded()))" } ?? "--"
    }

    /// "172".
    public static func energy(_ kilocalories: Double) -> String {
        "\(Int(kilocalories.rounded()))"
    }

    /// "128 ppm", o "--" sin medidas: el pulso medio del resumen.
    public static func averageHeartRate(_ beatsPerMinute: Double?) -> String {
        beatsPerMinute.map { "\(heartRate($0)) ppm" } ?? "--"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
