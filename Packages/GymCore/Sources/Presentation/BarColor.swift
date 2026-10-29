import Domain

/// Escala de intensidad del grupo «por debajo del objetivo»: por volumen o, si todas empatan, por
/// 1RM estimado.
public struct BelowTargetScale: Hashable, Sendable {
    public let useE1RM: Bool
    public let range: ClosedRange<Double>

    public init(useE1RM: Bool, range: ClosedRange<Double>) {
        self.useE1RM = useE1RM
        self.range = range
    }
}

/// Color de las barras de la tira de historial (`builders.js` de la PWA). El tono dice si se
/// cumplió el objetivo (naranja = mismo peso sin cumplirlo; azul = el resto) y la intensidad, cuánto
/// se rindió frente a las demás barras de ese color. En la PWA, sin cumplir era verde: en la app el
/// verde es «sincronizado» o «bien» (repaso de la HIG, 2026-10-28), y naranja es lo mismo que en las
/// series de la tarjeta. Nunca se mide contra el objetivo, que es un
/// número que se teclea, sino contra lo hecho.
public enum BarColor {
    static let blueFloor = RGB(r: 0x1E, g: 0x3A, b: 0x50)
    static let blueVivid = RGB(r: 0x56, g: 0x9C, b: 0xD6)
    static let belowVivid = RGB(r: 206, g: 145, b: 120)
    static let belowFloor = RGB(r: 103, g: 72, b: 60)

    /// Por debajo si no cumplió el objetivo y tiene el mismo peso que la referencia (sin referencia,
    /// solo manda el objetivo).
    public static func isBelowTarget(_ log: ExerciseLog, referenceWeight: Double? = nil) -> Bool {
        let sameWeight = referenceWeight.map { log.weight == $0 } ?? true
        return log.repShortfall > 0 && sameWeight
    }

    /// A igual peso, el volumen ordena por trabajo hecho; si todas empatan, desempata el 1RM.
    public static func belowTargetScale(_ logs: [ExerciseLog]) -> BelowTargetScale {
        guard !logs.isEmpty else { return BelowTargetScale(useE1RM: false, range: 0...0) }
        let volumes = logs.map(\.volume)
        let useE1RM = volumes.allSatisfy { $0 == volumes[0] }
        let values = useE1RM ? logs.map(\.primaryMetric) : volumes
        return BelowTargetScale(useE1RM: useE1RM, range: values.min()!...values.max()!)
    }

    /// `blueRange`: mínimo y máximo de `blueMetric` entre las barras azules visibles (por defecto,
    /// la métrica principal; la tira usa su nivel).
    public static func color(_ log: ExerciseLog, blueRange: ClosedRange<Double>, belowTargetScale: BelowTargetScale,
                             referenceWeight: Double? = nil, blueMetric: Double? = nil) -> RGB {
        guard isBelowTarget(log, referenceWeight: referenceWeight) else {
            return interpolate(blueFloor, blueVivid, fraction(blueMetric ?? log.primaryMetric, in: blueRange))
        }
        let metric = belowTargetScale.useE1RM ? log.primaryMetric : log.volume
        return interpolate(belowFloor, belowVivid, fraction(metric, in: belowTargetScale.range))
    }

    private static func fraction(_ value: Double, in range: ClosedRange<Double>) -> Double {
        range.upperBound == range.lowerBound ? 1 : (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Como `Math.round` de JS en cada canal.
    private static func interpolate(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        func channel(_ x: Int, _ y: Int) -> Int { Int(jsRound(Double(x) + Double(y - x) * t)) }
        return RGB(r: channel(a.r, b.r), g: channel(a.g, b.g), b: channel(a.b, b.b))
    }
}
