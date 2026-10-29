import XCTest

/// Lo que dice VoiceOver en la tarjeta del entreno (2026-10-27): cada control dice qué es y cada
/// serie, cómo va. Antes los «−» y «+» solo decían «menos» y «más», y cada serie, un número.
final class AccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaTarjetaDelEntrenoSeEntiendeConVoiceOver() {
        let app = XCUIApplication.launchDemo()
        app.startWorkout()
        app.buttons[AccessibilityID.card("press_banca")].firstMatch.tap()

        // Un botón dice lo que hace, con su verbo; antes, «+ Ejercicio» y VoiceOver solo decía
        // «Ejercicio» (repaso de la HIG, 2026-10-28).
        XCTAssertEqual(app.buttons[AccessibilityID.addExercise].label, "Añadir ejercicio")
        XCTAssertEqual(app.buttons[AccessibilityID.parameter(.weight, .plus)].firstMatch.label, "Subir peso")
        XCTAssertEqual(app.buttons[AccessibilityID.parameter(.weight, .minus)].firstMatch.label, "Bajar peso")
        XCTAssertEqual(app.buttons[AccessibilityID.parameter(.targetReps, .plus)].firstMatch.label, "Subir repeticiones objetivo")
        let weight = app.textFields[AccessibilityID.parameter(.weight, .field)].firstMatch
        XCTAssertEqual(weight.label, "Peso")
        XCTAssertTrue((weight.value as? String)?.hasSuffix("kilos") == true, "\(weight.value ?? "")")

        let series = app.descendants(matching: .any)[AccessibilityID.series(0)].firstMatch
        XCTAssertTrue(series.appears(timeout: 5))
        XCTAssertEqual(series.label, "Serie 1")
        let value = series.value as? String ?? ""
        XCTAssertTrue(value.contains("repeticiones") || value.contains("repetición") || value == "Sin completar", value)
    }
}
