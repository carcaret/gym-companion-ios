/// Lo que mide el reloj mientras dura el entreno (la sesión de Salud): el pulso de ahora y las
/// kcal acumuladas.
public struct WorkoutMetrics: Hashable, Sendable {
    /// Pulsaciones por minuto; `nil` hasta la primera medida.
    public var heartRate: Double?
    /// Kcal activas.
    public var activeEnergy: Double
    /// Kcal totales: las activas más las de reposo.
    public var totalEnergy: Double

    public init(heartRate: Double? = nil, activeEnergy: Double = 0, totalEnergy: Double = 0) {
        self.heartRate = heartRate
        self.activeEnergy = activeEnergy
        self.totalEnergy = totalEnergy
    }
}

/// El entreno terminado, tal como se guarda en Salud.
public struct WorkoutSummary: Hashable, Sendable {
    public var duration: Duration
    public var activeEnergy: Double
    public var totalEnergy: Double
    /// Pulsaciones por minuto de media; `nil` si no hubo ninguna medida.
    public var averageHeartRate: Double?

    public init(duration: Duration, activeEnergy: Double, totalEnergy: Double, averageHeartRate: Double?) {
        self.duration = duration
        self.activeEnergy = activeEnergy
        self.totalEnergy = totalEnergy
        self.averageHeartRate = averageHeartRate
    }
}
