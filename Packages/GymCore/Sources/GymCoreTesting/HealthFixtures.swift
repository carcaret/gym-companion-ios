import Domain

/// Medidas de ejemplo de Salud, para los tests.
public enum HealthFixtures {
    public static let spain = 3600
    public static let fitdays = HealthSource(bundleID: "com.fitdays.fitdays", name: "Fitdays")
    public static let macroFactor = HealthSource(bundleID: "com.sbs.diet", name: "MacroFactor")
    public static let scaleDevice = HealthDevice(name: "Báscula", manufacturer: "Healthkeep", model: "FG2016LB")

    public static func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0,
                          offset: Int = spain) -> Instant {
        Instant(LocalDate(year: year, month: month, day: day)!, hour: hour, minute: minute, second: second, utcOffsetSeconds: offset)!
    }

    /// Lo que escribe la báscula en un pesaje (peso, % de grasa y masa sin grasa a la vez).
    public static func weighing(_ id: String, at time: Instant, weight: Double, fat: Double, lean: Double,
                                device: HealthDevice? = nil) -> [HealthSample] {
        [
            HealthSample(id: id, quantity: .bodyMass, value: weight, start: time, source: fitdays, device: device),
            HealthSample(id: "\(id)-grasa", quantity: .bodyFatPercentage, value: fat, start: time, source: fitdays, device: device),
            HealthSample(id: "\(id)-magra", quantity: .leanBodyMass, value: lean, start: time, source: fitdays, device: device),
        ]
    }

    public static let samples: [HealthSample] = weighing("p1", at: at(2026, 10, 31, 8, 2, 11), weight: 73.1, fat: 19.7, lean: 58.7)
        + weighing("p2", at: at(2026, 11, 1, 9, 27, 38), weight: 73.3, fat: 19.8, lean: 58.79, device: scaleDevice)
        + [
            HealthSample(id: "mf", quantity: .bodyMass, value: 72.8, start: at(2025, 7, 4, 0, 0), end: at(2025, 7, 4, 23, 59, 59),
                         source: macroFactor),
            HealthSample(id: "c1", quantity: .waistCircumference, value: 82.5, start: at(2026, 10, 20, 8, 15, offset: 7200),
                         source: HealthSource(bundleID: "com.apple.Health", name: "Salud")),
            HealthSample(id: "k1", quantity: .dietaryEnergy, value: 2531, start: at(2026, 10, 31, 9, 0), source: macroFactor),
            HealthSample(id: "q1", quantity: .protein, value: 160.5, start: at(2026, 10, 31, 9, 0), source: macroFactor),
            HealthSample(id: "k2", quantity: .dietaryEnergy, value: 1200, start: at(2026, 11, 1, 10, 0), source: macroFactor),
        ]

    public static let record = HealthRecord(samples: samples)
}
