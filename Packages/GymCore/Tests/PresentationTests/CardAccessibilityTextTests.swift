import Domain
import Presentation
import Testing

// Propio de la app (2026-10-27): lo que dice VoiceOver en la tarjeta de un ejercicio. En la PWA
// solo había iconos y números.
@Suite("VoiceOver en la tarjeta del ejercicio")
struct CardAccessibilityTextTests {
    @Test("cada parámetro tiene nombre, y sus botones dicen qué suben o bajan")
    func parameters() {
        #expect(CardAccessibilityText.name(.weight) == "Peso")
        #expect(CardAccessibilityText.name(.series) == "Series")
        #expect(CardAccessibilityText.name(.targetReps) == "Repeticiones objetivo")
        #expect(CardAccessibilityText.increase(.weight) == "Subir peso")
        #expect(CardAccessibilityText.decrease(.targetReps) == "Bajar repeticiones objetivo")
    }

    @Test("el peso dice sus kilos, y el valor de un parámetro con error lo dice")
    func parameterValue() {
        #expect(CardAccessibilityText.value(.weight, "62,5", hasError: false) == "62,5 kilos")
        #expect(CardAccessibilityText.value(.series, "3", hasError: false) == "3")
        #expect(CardAccessibilityText.value(.targetReps, "0", hasError: true) == "0, con error")
    }

    @Test("cada serie dice su número, sus repeticiones y si llega al objetivo")
    func series() {
        #expect(CardAccessibilityText.seriesLabel(0) == "Serie 1")
        #expect(CardAccessibilityText.seriesValue(10, target: 10, hasError: false) == "10 repeticiones, objetivo cumplido")
        #expect(CardAccessibilityText.seriesValue(12, target: 10, hasError: false) == "12 repeticiones, objetivo cumplido")
        #expect(CardAccessibilityText.seriesValue(8, target: 10, hasError: false) == "8 repeticiones, por debajo del objetivo")
        #expect(CardAccessibilityText.seriesValue(1, target: 10, hasError: false) == "1 repetición, por debajo del objetivo")
        #expect(CardAccessibilityText.seriesValue(nil, target: 10, hasError: false) == "Sin completar")
        #expect(CardAccessibilityText.seriesValue(nil, target: 10, hasError: true) == "Sin completar, con error")
    }
}
