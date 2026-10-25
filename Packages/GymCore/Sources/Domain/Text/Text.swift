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

extension ExerciseID {
    /// Id para un ejercicio nuevo a partir de su nombre: minúsculas, sin tildes ni eñes, espacios
    /// a "_" y nada más que letras, números y "_" ("Curl de Bíceps" → "curl_de_biceps").
    ///
    /// Igual que en la PWA, para que las dos generen el mismo id mientras convivan: la diéresis
    /// no se convierte, se elimina ("Pingüino" → "pingino").
    public static func slug(from name: String) -> String {
        let replacements: [Character: Character] = [
            "á": "a", "à": "a", "é": "e", "è": "e", "í": "i", "ì": "i",
            "ó": "o", "ò": "o", "ú": "u", "ù": "u", "ñ": "n",
        ]
        var slug = ""
        var inWhitespace = false
        for character in name.lowercased() {
            if character.isWhitespace {
                if !inWhitespace { slug.append("_") }
                inWhitespace = true
                continue
            }
            inWhitespace = false
            let base = replacements[character] ?? character
            if base == "_" || (base.isASCII && (base.isLetter || base.isNumber)) { slug.append(base) }
        }
        return slug
    }
}

/// Orden alfabético en español, como `localeCompare(…, 'es')` de la PWA: primero por letras sin
/// distinguir tildes ni mayúsculas (con la ñ entre la n y la o y los espacios antes que las
/// letras); a igualdad, sin tilde antes que con tilde; y después, minúscula antes que mayúscula.
public enum SpanishCollation {
    public static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        for level in [primary, secondary, tertiary] {
            let (a, b) = (level(lhs), level(rhs))
            if a != b { return a.lexicographicallyPrecedes(b) }
        }
        return false
    }

    private static func primary(_ text: String) -> [UInt32] {
        text.lowercased().map { character in
            if character == "ñ" { return weight("n") + 1 }
            return weight(String.baseLetters[character] ?? character)
        }
    }

    private static func secondary(_ text: String) -> [UInt32] {
        text.lowercased().map { weight($0) }
    }

    private static func tertiary(_ text: String) -> [UInt32] {
        text.map { $0.isUppercase ? 1 : 0 }
    }

    /// Peso de un carácter: el doble de su código, para dejar hueco a la ñ justo después de la n.
    private static func weight(_ character: Character) -> UInt32 {
        (character.unicodeScalars.first?.value ?? 0) * 2
    }
}
