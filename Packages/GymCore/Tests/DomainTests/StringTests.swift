import Domain
import Testing

// slugifyExerciseName, portados de tests/unit/formatting.test.js de la PWA. El orden alfabético
// en español (`localeCompare(…, 'es')` en la PWA) no tenía tests propios: se añaden.

@Suite("slugifyExerciseName")
struct SlugTests {
    @Test("convierte tildes")
    func accents() { #expect(ExerciseID.slug(from: "Curl de Bíceps") == "curl_de_biceps") }

    @Test("convierte eñes")
    func enie() { #expect(ExerciseID.slug(from: "Año Nuevo") == "ano_nuevo") }

    @Test("convierte espacios a guion bajo")
    func spaces() { #expect(ExerciseID.slug(from: "Press Arnold") == "press_arnold") }

    @Test("elimina caracteres raros")
    func odd() { #expect(ExerciseID.slug(from: "Press (banca)") == "press_banca") }

    @Test("convierte múltiples espacios")
    func manySpaces() { #expect(ExerciseID.slug(from: "press   banca") == "press_banca") }

    @Test("string vacío → string vacío")
    func empty() { #expect(ExerciseID.slug(from: "") == "") }

    @Test("solo caracteres especiales → string vacío")
    func onlySpecial() { #expect(ExerciseID.slug(from: "!!@@##$$") == "") }

    @Test("números → se mantienen")
    func digits() { #expect(ExerciseID.slug(from: "press 21s") == "press_21s") }

    @Test("nombre ya en formato slug → sin cambio")
    func already() { #expect(ExerciseID.slug(from: "press_banca") == "press_banca") }

    @Test("mayúsculas mezcladas → todo lowercase")
    func mixedCase() { #expect(ExerciseID.slug(from: "Press BANCA Inclinado") == "press_banca_inclinado") }
}

@Suite("Orden alfabético en español")
struct SpanishCollationTests {
    private func sorted(_ names: [String]) -> [String] { names.sorted(by: SpanishCollation.precedes) }

    @Test("sin distinguir mayúsculas")
    func caseInsensitive() {
        #expect(sorted(["Zancadas", "curl", "Press banca"]) == ["curl", "Press banca", "Zancadas"])
    }

    @Test("las tildes no cuentan para el orden principal")
    func accents() {
        #expect(sorted(["Remo", "Jalón al pecho", "Jalon"]) == ["Jalon", "Jalón al pecho", "Remo"])
        #expect(sorted(["Curl bíceps", "Curl barra"]) == ["Curl barra", "Curl bíceps"])
    }

    @Test("la ñ va entre la n y la o")
    func enie() {
        #expect(sorted(["oso", "ñu", "nube"]) == ["nube", "ñu", "oso"])
    }

    @Test("el espacio va antes que las letras")
    func space() {
        #expect(sorted(["Apertura Mancuerna", "Apertura con Cable", "Aperturas"]) == ["Apertura con Cable", "Apertura Mancuerna", "Aperturas"])
    }

    @Test("a igualdad de letras, sin tilde antes que con tilde")
    func accentTiebreak() {
        #expect(SpanishCollation.precedes("Jalon", "Jalón"))
        #expect(!SpanishCollation.precedes("Jalón", "Jalon"))
    }

    @Test("a igualdad de todo lo demás, minúscula antes que mayúscula")
    func caseTiebreak() {
        #expect(SpanishCollation.precedes("remo", "Remo"))
        #expect(!SpanishCollation.precedes("Remo", "remo"))
        #expect(!SpanishCollation.precedes("Remo", "Remo"))
    }
}

@Suite("Búsqueda sin tildes")
struct FoldingTests {
    @Test("ignora tildes, diéresis, eñes y mayúsculas, como normalize('NFD') de la PWA")
    func folds() {
        #expect("Jalón AL Pecho".searchFolded == "jalon al pecho")
        #expect("Pingüino Año".searchFolded == "pinguino ano")
    }
}
