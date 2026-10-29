/// `Math.round` de JavaScript: la mitad redondea hacia +∞ (−2,5 → −2), no lejos del cero.
public func jsRound(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
}
