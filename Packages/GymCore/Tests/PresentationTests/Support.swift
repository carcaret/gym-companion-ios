import Domain

// Literales cómodos para los tests (copia de los de DomainTests: cada target de tests es su módulo).
// En el código de producción las fechas se leen con `LocalDate(iso:)`, que puede fallar.
extension LocalDate: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let date = LocalDate(iso: value) else { fatalError("Fecha de test inválida: \(value)") }
        self = date
    }
}

extension LocalDate {
    init(_ iso: String) { self.init(stringLiteral: iso) }
}

/// Equivalente a `toBeCloseTo(expected, digits)` de Vitest: |a − b| < 10^−digits / 2.
func isClose(_ actual: Double, _ expected: Double, digits: Int = 2) -> Bool {
    var tolerance = 0.5
    for _ in 0..<digits { tolerance /= 10 }
    return abs(actual - expected) < tolerance
}
