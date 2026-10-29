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
