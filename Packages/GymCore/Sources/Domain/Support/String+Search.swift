extension String {
    /// Para buscar: en minúsculas y sin tildes, diéresis ni eñes ("Jalón" → "jalon"). Equivale al
    /// `normalize('NFD')` + quitar marcas de la PWA para los caracteres del español.
    public var searchFolded: String {
        String(lowercased().map { Self.baseLetters[$0] ?? $0 })
    }

    /// Sin espacios ni saltos de línea al principio ni al final (el `trim()` de JS).
    public func trimmingWhitespace() -> String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }

    static let baseLetters: [Character: Character] = [
        "á": "a", "à": "a", "ä": "a", "â": "a", "ã": "a",
        "é": "e", "è": "e", "ë": "e", "ê": "e",
        "í": "i", "ì": "i", "ï": "i", "î": "i",
        "ó": "o", "ò": "o", "ö": "o", "ô": "o", "õ": "o",
        "ú": "u", "ù": "u", "ü": "u", "û": "u",
        "ñ": "n", "ç": "c",
    ]
}
