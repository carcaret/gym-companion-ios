import Domain

/// Números tecleados en los campos del entreno.
public enum NumericInput {
    /// Como `parseFloat` de la PWA: el número del principio del texto (ignorando espacios
    /// delante y lo que venga detrás), o `nil` si no empieza por un número. Admite coma decimal,
    /// que es lo que escribe el teclado numérico de iOS en español.
    public static func decimal(_ text: String) -> Double? {
        var rest = Substring(text.drop(while: \.isWhitespace))
        let sign = takeSign(&rest)
        let whole = takeDigits(&rest)
        var fraction = ""
        if let separator = rest.first, separator == "." || separator == "," {
            rest.removeFirst()
            fraction = takeDigits(&rest)
        }
        guard !whole.isEmpty || !fraction.isEmpty else { return nil }
        return Double("\(sign)\(whole.isEmpty ? "0" : whole).\(fraction.isEmpty ? "0" : fraction)")
    }

    /// Como `parseInt` de la PWA: el entero del principio, o `nil`.
    public static func integer(_ text: String) -> Int? {
        var rest = Substring(text.drop(while: \.isWhitespace))
        let sign = takeSign(&rest)
        return Int(sign + takeDigits(&rest))
    }

    private static func takeSign(_ text: inout Substring) -> String {
        guard let first = text.first, first == "-" || first == "+" else { return "" }
        text.removeFirst()
        return String(first)
    }

    private static func takeDigits(_ text: inout Substring) -> String {
        let digits = text.prefix { $0.isASCII && $0.isNumber }
        text.removeFirst(digits.count)
        return String(digits)
    }
}

extension ExerciseLog {
    /// Valor tecleado en el campo de peso, series u objetivo; ilegible = 0 (y luego los límites
    /// de `set(_:to:)`).
    public mutating func set(_ parameter: LogParameter, text: String) {
        set(parameter, to: NumericInput.decimal(text) ?? 0)
    }

    /// Reps tecleadas en una serie; vacío o ilegible deja la serie sin rellenar.
    public mutating func setRep(at index: Int, text: String) {
        setRep(at: index, to: NumericInput.integer(text))
    }
}
