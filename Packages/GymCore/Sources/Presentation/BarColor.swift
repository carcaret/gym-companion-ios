import Domain

/// Un color RGB de 0 a 255.
public struct RGB: Hashable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// "rgb(30,58,80)", como el CSS de la PWA.
    public var text: String { "rgb(\(r),\(g),\(b))" }
}

/// Escala de intensidad del grupo verde: por volumen o, si todas empatan, por 1RM estimado.
public struct GreenScale: Hashable, Sendable {
    public let useE1RM: Bool
    public let range: ClosedRange<Double>

    public init(useE1RM: Bool, range: ClosedRange<Double>) {
        self.useE1RM = useE1RM
        self.range = range
    }
}

/// Color de las barras de la tira de historial (`builders.js` de la PWA). El tono dice si se
/// cumplió el objetivo (verde = mismo peso sin cumplirlo; azul = el resto) y la intensidad, cuánto
/// se rindió frente a las demás barras de ese color. Nunca se mide contra el objetivo, que es un
/// número que se teclea, sino contra lo hecho.
public enum BarColor {
    static let blueFloor = RGB(r: 0x1E, g: 0x3A, b: 0x50)
    static let blueVivid = RGB(r: 0x56, g: 0x9C, b: 0xD6)
    static let greenVivid = RGB(r: 93, g: 202, b: 165)
    static let greenFloor = RGB(r: 36, g: 86, b: 70)

    /// Verde si no cumplió el objetivo y tiene el mismo peso que la referencia (sin referencia,
    /// solo manda el objetivo).
    public static func isGreen(_ log: ExerciseLog, referenceWeight: Double? = nil) -> Bool {
        let sameWeight = referenceWeight.map { log.weight == $0 } ?? true
        return log.repShortfall > 0 && sameWeight
    }

    /// A igual peso, el volumen ordena por trabajo hecho; si todas empatan, desempata el 1RM.
    public static func greenScale(_ logs: [ExerciseLog]) -> GreenScale {
        guard !logs.isEmpty else { return GreenScale(useE1RM: false, range: 0...0) }
        let volumes = logs.map(\.volume)
        let useE1RM = volumes.allSatisfy { $0 == volumes[0] }
        let values = useE1RM ? logs.map(\.primaryMetric) : volumes
        return GreenScale(useE1RM: useE1RM, range: values.min()!...values.max()!)
    }

    /// `blueRange`: mínimo y máximo de `blueMetric` entre las barras azules visibles (por defecto,
    /// la métrica principal; la tira usa su nivel).
    public static func color(_ log: ExerciseLog, blueRange: ClosedRange<Double>, greenScale: GreenScale,
                             referenceWeight: Double? = nil, blueMetric: Double? = nil) -> RGB {
        guard isGreen(log, referenceWeight: referenceWeight) else {
            return interpolate(blueFloor, blueVivid, fraction(blueMetric ?? log.primaryMetric, in: blueRange))
        }
        let metric = greenScale.useE1RM ? log.primaryMetric : log.volume
        return interpolate(greenFloor, greenVivid, fraction(metric, in: greenScale.range))
    }

    private static func fraction(_ value: Double, in range: ClosedRange<Double>) -> Double {
        range.upperBound == range.lowerBound ? 1 : (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Como `Math.round` de JS en cada canal.
    private static func interpolate(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        func channel(_ x: Int, _ y: Int) -> Int { Int((Double(x) + Double(y - x) * t + 0.5).rounded(.down)) }
        return RGB(r: channel(a.r, b.r), g: channel(a.g, b.g), b: channel(a.b, b.b))
    }
}
