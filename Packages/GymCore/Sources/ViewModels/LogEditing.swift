import Domain

/// Lo que se está editando en una lista de tarjetas de ejercicio (el entreno en curso y el editor
/// del Historial): la serie enfocada, lo tecleado que aún no se ha aplicado y los errores que marcó
/// la última validación, por posición.
struct LogEditing {
    /// La serie enfocada, que enseña los chips.
    private(set) var focusedSeries: (log: Int, series: Int)?
    /// Lo tecleado en un campo que aún no se ha aplicado (`TypedValue`).
    private(set) var typed: TypedValue?
    var validationErrors: [Int: [LogValidationError]] = [:]

    /// La serie enfocada del log `index`, si la hay.
    func focusedSeries(at index: Int) -> Int? {
        focusedSeries?.log == index ? focusedSeries?.series : nil
    }

    /// Tocar una serie enseña sus chips; tocarla otra vez los esconde.
    mutating func focus(_ series: Int, at index: Int) {
        if let focused = focusedSeries, focused.log == index, focused.series == series {
            focusedSeries = nil
        } else {
            focusedSeries = (index, series)
        }
    }

    mutating func unfocus() {
        focusedSeries = nil
    }

    /// Cerrar la tarjeta `index` quita el foco de sus series.
    mutating func unfocus(at index: Int) {
        if focusedSeries?.log == index { focusedSeries = nil }
    }

    mutating func type(_ parameter: LogParameter, text: String, at index: Int) {
        typed = TypedValue(parameter: parameter, text: text, index: index)
    }

    /// Lo tecleado pendiente, que deja de estarlo.
    mutating func takeTyped() -> TypedValue? {
        defer { typed = nil }
        return typed
    }

    mutating func reset() {
        self = LogEditing()
    }
}
