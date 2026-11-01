/// Una báscula: de dónde vienen sus pesajes. Salud no dice qué báscula es, sino qué app escribió
/// la medida y, a veces, con qué aparato: eso la identifica. Dos básculas que usen la misma app sin
/// decir el aparato no se distinguen solas.
public struct Scale: Hashable, Sendable {
    public typealias ID = String

    public var id: ID
    public var source: HealthSource
    public var device: HealthDevice?
    public var firstMeasurement: MeasurementTime
    public var lastMeasurement: MeasurementTime

    public init(id: ID, source: HealthSource, device: HealthDevice?, firstMeasurement: MeasurementTime,
                lastMeasurement: MeasurementTime) {
        self.id = id
        self.source = source
        self.device = device
        self.firstMeasurement = firstMeasurement
        self.lastMeasurement = lastMeasurement
    }

    /// La app y, si lo hay, el aparato: el modelo o, sin él, el nombre.
    public static func id(source: HealthSource, device: HealthDevice?) -> ID {
        guard let device = device?.model ?? device?.name else { return source.bundleID }
        return "\(source.bundleID)#\(device)"
    }
}

/// Un pesaje: lo que la báscula escribe a la vez (peso, % de grasa y masa sin grasa). Lo que no
/// escribió, `nil` (un peso apuntado a mano no trae grasa).
public struct Weighing: Hashable, Sendable {
    /// El de la medida del peso en Salud (o, sin peso, el de la primera).
    public var id: String
    public var time: MeasurementTime
    public var scaleID: Scale.ID
    public var weightKg: Double?
    public var bodyFatPercent: Double?
    public var leanMassKg: Double?

    public init(id: String, time: MeasurementTime, scaleID: Scale.ID, weightKg: Double? = nil, bodyFatPercent: Double? = nil,
                leanMassKg: Double? = nil) {
        self.id = id
        self.time = time
        self.scaleID = scaleID
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.leanMassKg = leanMassKg
    }
}

/// Una medida del perímetro de la cintura.
public struct WaistMeasurement: Hashable, Sendable {
    public var id: String
    public var time: MeasurementTime
    public var centimeters: Double

    public init(id: String, time: MeasurementTime, centimeters: Double) {
        self.id = id
        self.time = time
        self.centimeters = centimeters
    }
}

/// Lo comido un día según una app (MacroFactor): la suma de lo que apuntó. Lo que no apuntó, `nil`.
public struct DailyNutrition: Hashable, Sendable {
    public var date: LocalDate
    /// El nombre de la app.
    public var source: String
    public var kilocalories: Double?
    public var proteinGrams: Double?
    public var fatGrams: Double?
    public var carbohydrateGrams: Double?

    public init(date: LocalDate, source: String, kilocalories: Double? = nil, proteinGrams: Double? = nil, fatGrams: Double? = nil,
                carbohydrateGrams: Double? = nil) {
        self.date = date
        self.source = source
        self.kilocalories = kilocalories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbohydrateGrams = carbohydrateGrams
    }
}

/// Lo de Salud que se guarda para analizarlo (el `salud.json`): las medidas tal cual, sin
/// tendencias ni filtros, que son cosa del análisis y pueden cambiar. Salud manda: se rehace entero
/// con lo que haya en cada momento.
public struct HealthRecord: Hashable, Sendable {
    /// Por la primera medida.
    public var scales: [Scale]
    /// Por fecha.
    public var weighings: [Weighing]
    /// Por fecha.
    public var waist: [WaistMeasurement]
    /// Por fecha y app.
    public var nutrition: [DailyNutrition]

    public init(scales: [Scale] = [], weighings: [Weighing] = [], waist: [WaistMeasurement] = [], nutrition: [DailyNutrition] = []) {
        self.scales = scales
        self.weighings = weighings
        self.waist = waist
        self.nutrition = nutrition
    }

    /// Sin nada que guardar: Salud no tiene datos o no deja leerlos (iOS no dice si se negó el permiso).
    public var isEmpty: Bool { weighings.isEmpty && waist.isEmpty && nutrition.isEmpty }

    /// Cuánto hay, para enseñarlo.
    public var summary: Summary {
        Summary(weighings: weighings.count, waistMeasurements: waist.count, nutritionDays: Set(nutrition.map(\.date)).count)
    }

    public struct Summary: Hashable, Sendable {
        public var weighings: Int
        public var waistMeasurements: Int
        public var nutritionDays: Int

        public init(weighings: Int, waistMeasurements: Int, nutritionDays: Int) {
            self.weighings = weighings
            self.waistMeasurements = waistMeasurements
            self.nutritionDays = nutritionDays
        }
    }
}
