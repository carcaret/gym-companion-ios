/// Lo que se lee de Salud: las medidas del cuerpo y lo comido.
public enum HealthQuantity: Hashable, CaseIterable, Sendable {
    /// kg.
    case bodyMass
    /// % (0–100).
    case bodyFatPercentage
    /// kg (la «masa corporal sin grasa» de Salud).
    case leanBodyMass
    /// cm.
    case waistCircumference
    /// kcal.
    case dietaryEnergy
    /// g.
    case protein
    /// g.
    case fat
    /// g.
    case carbohydrates

    /// Lo que escribe una báscula en cada pesaje.
    public var isWeighing: Bool {
        switch self {
        case .bodyMass, .bodyFatPercentage, .leanBodyMass: true
        default: false
        }
    }

    public var isNutrition: Bool {
        switch self {
        case .dietaryEnergy, .protein, .fat, .carbohydrates: true
        default: false
        }
    }
}

/// La app que escribió una medida en Salud.
public struct HealthSource: Hashable, Sendable {
    /// El identificador de la app, el que no cambia (p. ej. `com.apple.Health` lo apuntado a mano).
    public var bundleID: String
    /// El nombre que enseña Salud («Fitdays»).
    public var name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// El aparato que tomó una medida, si la app lo dice (la de la báscula Healthkeep no lo dice).
public struct HealthDevice: Hashable, Sendable {
    public var name: String?
    public var manufacturer: String?
    public var model: String?

    public init(name: String? = nil, manufacturer: String? = nil, model: String? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
    }

    /// Sin ningún dato no dice nada.
    public var isEmpty: Bool { name == nil && manufacturer == nil && model == nil }
}

/// Una medida de Salud tal cual, en la unidad de su `quantity`.
public struct HealthSample: Hashable, Sendable {
    /// El de Salud: no cambia.
    public var id: String
    public var quantity: HealthQuantity
    public var value: Double
    public var start: Instant
    public var end: Instant
    public var source: HealthSource
    public var device: HealthDevice?

    public init(id: String, quantity: HealthQuantity, value: Double, start: Instant, end: Instant? = nil,
                source: HealthSource, device: HealthDevice? = nil) {
        self.id = id
        self.quantity = quantity
        self.value = value
        self.start = start
        self.end = end ?? start
        self.source = source
        self.device = device.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var time: MeasurementTime { MeasurementTime(start: start, end: end) }
}
