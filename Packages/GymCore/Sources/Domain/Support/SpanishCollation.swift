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
