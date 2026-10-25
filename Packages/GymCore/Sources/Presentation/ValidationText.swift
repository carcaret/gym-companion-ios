import Domain

/// Mensajes de error para la interfaz.
public enum ValidationText {
    public static func message(_ error: LogValidationError) -> String {
        switch error {
        case .negativeWeight: "Peso debe ser >= 0"
        case .invalidSeries: "Series debe ser >= 1"
        case .invalidTargetReps: "Reps objetivo debe ser >= 1"
        case .missingRep(let index): "Serie \(index + 1) no completada"
        case .invalidRep(let index): "Serie \(index + 1) inválida"
        }
    }

    public static func message(_ error: CatalogError) -> String {
        switch error {
        case .notFound: "El ejercicio no existe"
        case .emptyName: "El nombre no puede estar vacío"
        case .invalidGroup: "Grupo no válido"
        }
    }
}
