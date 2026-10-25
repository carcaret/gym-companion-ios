/// Por qué un ejercicio no se puede dar por terminado.
public enum LogValidationError: Hashable, Sendable {
    case negativeWeight
    case invalidSeries
    case invalidTargetReps
    /// Serie sin rellenar.
    case missingRep(index: Int)
    /// Serie con reps negativas.
    case invalidRep(index: Int)

    /// La serie afectada, si el error es de una serie.
    public var repIndex: Int? {
        switch self {
        case .missingRep(let index), .invalidRep(let index): index
        default: nil
        }
    }
}

extension ExerciseLog {
    /// Errores en el orden de la PWA: peso, series, objetivo y cada serie.
    public var validationErrors: [LogValidationError] {
        var errors: [LogValidationError] = []
        if weight < 0 { errors.append(.negativeWeight) }
        if series < 1 { errors.append(.invalidSeries) }
        if targetReps < 1 { errors.append(.invalidTargetReps) }
        for index in 0..<max(0, series) {
            guard let reps = rep(at: index) else {
                errors.append(.missingRep(index: index))
                continue
            }
            if reps < 0 { errors.append(.invalidRep(index: index)) }
        }
        return errors
    }
}

/// Resultado de validar una sesión: los errores de cada ejercicio, por su posición.
public struct SessionValidation: Hashable, Sendable {
    public let errorsByLog: [Int: [LogValidationError]]

    public var isValid: Bool { errorsByLog.isEmpty }
}

extension Session {
    /// Los ejercicios saltados no se validan.
    public var validation: SessionValidation {
        var errors: [Int: [LogValidationError]] = [:]
        for (index, log) in logs.enumerated() where !log.skipped {
            let logErrors = log.validationErrors
            if !logErrors.isEmpty { errors[index] = logErrors }
        }
        return SessionValidation(errorsByLog: errors)
    }
}
