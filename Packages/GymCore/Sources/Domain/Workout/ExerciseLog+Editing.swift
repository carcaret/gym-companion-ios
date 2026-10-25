/// Lo que se puede ajustar de un ejercicio con los botones −/+ o tecleando.
public enum LogParameter: Sendable {
    case weight, series, targetReps
}

extension ExerciseLog {
    /// Log nuevo a partir de `seed`: las reps hechas se prerrellenan con las de la semilla (las
    /// series vacías y las que falten, con el objetivo), para que un entreno recién creado ya sea
    /// válido. (`buildLog` en la PWA.)
    public init(planning exerciseID: ExerciseID, from seed: LogSeed) {
        let actual: [Int?] = (0..<max(0, seed.series)).map { index in
            index < seed.actualReps.count ? seed.actualReps[index] ?? seed.targetReps : seed.targetReps
        }
        self.init(exerciseID: exerciseID, series: seed.series, targetReps: seed.targetReps, actualReps: actual, weight: seed.weight)
    }

    /// Escalón de los botones −/+ de peso: cargas ligeras piden ajustes finos y las pesadas, saltos
    /// grandes. <20 kg → 1 kg; 20–49,9 kg → 2 kg; ≥50 kg → 5 kg.
    public static func weightStep(for weight: Double) -> Double {
        if weight < 20 { return 1 }
        if weight < 50 { return 2 }
        return 5
    }

    /// Botones −/+. El peso se redondea a 0,1 kg y no baja de 0; las series no bajan de 1 (la
    /// nueva serie arranca con el objetivo); el objetivo no baja de 1 y arrastra a todas las reps.
    public mutating func adjust(_ parameter: LogParameter, by delta: Double) {
        switch parameter {
        case .weight:
            weight = max(0, jsRound((weight + delta) * 10) / 10)
        case .series:
            let newSeries = max(1, series + Int(delta))
            if newSeries > series { actualReps.append(targetReps) } else if newSeries < series { _ = actualReps.popLast() }
            series = newSeries
        case .targetReps:
            targetReps = max(1, targetReps + Int(delta))
            actualReps = actualReps.map { _ in targetReps }
        }
    }

    /// Valor tecleado (ya leído del texto; ilegible = 0). Mismos límites que `adjust`; las series
    /// y el objetivo se redondean al entero más cercano.
    public mutating func set(_ parameter: LogParameter, to value: Double) {
        switch parameter {
        case .weight:
            weight = max(0, value)
        case .series:
            let newSeries = max(1, Int(jsRound(value)))
            while actualReps.count < newSeries { actualReps.append(targetReps) }
            while actualReps.count > newSeries { actualReps.removeLast() }
            series = newSeries
        case .targetReps:
            targetReps = max(1, Int(jsRound(value)))
            actualReps = actualReps.map { _ in targetReps }
        }
    }

    /// −/+ de las reps de una serie; una serie vacía parte del objetivo. Nunca baja de 0.
    public mutating func adjustRep(at index: Int, by delta: Int) {
        let current = rep(at: index) ?? targetReps
        setRepValue(at: index, max(0, current + delta))
        syncTargetToMax()
    }

    /// Reps tecleadas en una serie; `nil` la deja vacía. Nunca baja de 0.
    public mutating func setRep(at index: Int, to value: Int?) {
        setRepValue(at: index, value.map { max(0, $0) })
        syncTargetToMax()
    }

    /// Alterna el salto. Reversible: no borra nada. Devuelve el estado nuevo.
    @discardableResult
    public mutating func toggleSkip() -> Bool {
        skipped.toggle()
        return skipped
    }

    func rep(at index: Int) -> Int? {
        actualReps.indices.contains(index) ? actualReps[index] : nil
    }

    private mutating func setRepValue(at index: Int, _ value: Int?) {
        while actualReps.count <= index { actualReps.append(nil) }
        actualReps[index] = value
    }

    /// Tras editar una serie, el objetivo sigue al máximo de las reps hechas (sube y baja). Si
    /// todas están vacías no cambia; nunca baja de 1.
    private mutating func syncTargetToMax() {
        guard let best = actualReps.compactMap({ $0 }).max() else { return }
        targetReps = max(1, best)
    }
}

/// `Math.round` de JavaScript: la mitad redondea hacia +∞ (−2,5 → −2), no lejos del cero.
func jsRound(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
}
