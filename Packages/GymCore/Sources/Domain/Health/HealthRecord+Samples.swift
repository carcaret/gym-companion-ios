extension HealthRecord {
    /// Lo que se guarda de las medidas de Salud:
    ///
    /// - Pesajes: lo que una misma app (y aparato) escribió en el mismo momento es un pesaje; si
    ///   repite una medida en ese momento, son dos pesajes. Cada app (y aparato) es una báscula.
    /// - Cintura: cada medida.
    /// - Nutrición: la suma de cada día (local) y app.
    /// - Valores redondeados a lo que mide cada cosa (kg y % con 2 decimales, cm y g con 1, kcal
    ///   enteras), para que el fichero no cambie por ruido de los decimales.
    /// - Todo en orden (fecha y luego id), para que lo mismo dé siempre el mismo fichero.
    public init(samples: [HealthSample]) {
        let samples = samples.sorted { ($0.time, $0.id) < ($1.time, $1.id) }
        let weighingSamples = samples.filter(\.quantity.isWeighing)
        self.init(
            scales: Self.scales(from: weighingSamples),
            weighings: Self.weighings(from: weighingSamples),
            waist: samples.filter { $0.quantity == .waistCircumference }.map {
                WaistMeasurement(id: $0.id, time: $0.time, centimeters: Self.rounded($0.value, decimals: 1))
            },
            nutrition: Self.nutrition(from: samples.filter(\.quantity.isNutrition))
        )
    }

    private static func scales(from samples: [HealthSample]) -> [Scale] {
        var scales: [Scale.ID: Scale] = [:]
        for sample in samples {
            let id = Scale.id(source: sample.source, device: sample.device)
            if var scale = scales[id] {
                scale.firstMeasurement = min(scale.firstMeasurement, sample.time)
                scale.lastMeasurement = max(scale.lastMeasurement, sample.time)
                scales[id] = scale
            } else {
                scales[id] = Scale(id: id, source: sample.source, device: sample.device, firstMeasurement: sample.time,
                                   lastMeasurement: sample.time)
            }
        }
        return scales.values.sorted { ($0.firstMeasurement, $0.id) < ($1.firstMeasurement, $1.id) }
    }

    private static func weighings(from samples: [HealthSample]) -> [Weighing] {
        struct Key: Hashable {
            var scaleID: Scale.ID
            var start: Instant
            var end: Instant
        }
        var order: [Key] = []
        var groups: [Key: [HealthSample]] = [:]
        for sample in samples {
            let key = Key(scaleID: Scale.id(source: sample.source, device: sample.device), start: sample.start, end: sample.end)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(sample)
        }
        return order.flatMap { key in weighings(in: groups[key]!, scaleID: key.scaleID) }
    }

    /// Las medidas de un mismo momento: cada una va al primer pesaje que aún no la tiene.
    private static func weighings(in group: [HealthSample], scaleID: Scale.ID) -> [Weighing] {
        var weighings: [Weighing] = []
        for sample in group {
            let index: Int
            if let free = weighings.firstIndex(where: { !$0.has(sample.quantity) }) {
                index = free
            } else {
                weighings.append(Weighing(id: sample.id, time: sample.time, scaleID: scaleID))
                index = weighings.endIndex - 1
            }
            weighings[index].set(sample.quantity, rounded(sample.value, decimals: 2))
            // El pesaje se llama como su peso.
            if sample.quantity == .bodyMass { weighings[index].id = sample.id }
        }
        return weighings
    }

    private static func nutrition(from samples: [HealthSample]) -> [DailyNutrition] {
        struct Key: Hashable, Comparable {
            var date: LocalDate
            var source: String

            static func < (lhs: Key, rhs: Key) -> Bool { (lhs.date, lhs.source) < (rhs.date, rhs.source) }
        }
        var totals: [Key: [HealthQuantity: Double]] = [:]
        for sample in samples {
            totals[Key(date: sample.start.localDate, source: sample.source.name), default: [:]][sample.quantity, default: 0] += sample.value
        }
        return totals.keys.sorted().map { key in
            let total = totals[key]!
            return DailyNutrition(
                date: key.date, source: key.source,
                kilocalories: total[.dietaryEnergy].map { rounded($0, decimals: 0) },
                proteinGrams: total[.protein].map { rounded($0, decimals: 1) },
                fatGrams: total[.fat].map { rounded($0, decimals: 1) },
                carbohydrateGrams: total[.carbohydrates].map { rounded($0, decimals: 1) }
            )
        }
    }

    static func rounded(_ value: Double, decimals: Int) -> Double {
        let scale = [1.0, 10, 100][decimals]
        return (value * scale).rounded() / scale
    }
}

private extension Weighing {
    func has(_ quantity: HealthQuantity) -> Bool {
        switch quantity {
        case .bodyMass: weightKg != nil
        case .bodyFatPercentage: bodyFatPercent != nil
        case .leanBodyMass: leanMassKg != nil
        default: false
        }
    }

    mutating func set(_ quantity: HealthQuantity, _ value: Double) {
        switch quantity {
        case .bodyMass: weightKg = value
        case .bodyFatPercentage: bodyFatPercent = value
        case .leanBodyMass: leanMassKg = value
        default: break
        }
    }
}
