import Domain
import Presentation
import Testing

// Portados de tests/unit/workout.test.js (validateLog, los que comprueban el mensaje) y de los
// mensajes de updateExercise (catalog.js) de la PWA.

@Suite("validateLog")
struct ValidationMessageTests {
    @Test("weight negativo → error en field weight")
    func weight() { #expect(ValidationText.message(.negativeWeight) == "Peso debe ser >= 0") }

    @Test("rep null en serie 0 → error con field rep, index 0")
    func missingRep() { #expect(ValidationText.message(.missingRep(index: 0)) == "Serie 1 no completada") }

    @Test("el resto de mensajes")
    func others() {
        #expect(ValidationText.message(.invalidSeries) == "Series debe ser >= 1")
        #expect(ValidationText.message(.invalidTargetReps) == "Reps objetivo debe ser >= 1")
        #expect(ValidationText.message(.invalidRep(index: 2)) == "Serie 3 inválida")
    }
}

@Suite("Mensajes del catálogo")
struct CatalogMessageTests {
    @Test("los de la PWA")
    func messages() {
        #expect(ValidationText.message(CatalogError.notFound) == "El ejercicio no existe")
        #expect(ValidationText.message(CatalogError.emptyName) == "El nombre no puede estar vacío")
        #expect(ValidationText.message(CatalogError.invalidGroup) == "Grupo no válido")
    }
}
