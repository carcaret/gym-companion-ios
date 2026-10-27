import XCTest

/// Lo que dice VoiceOver en la tarjeta del entreno (2026-10-27): cada control dice qué es y cada
/// serie, cómo va. Antes los «−» y «+» solo decían «menos» y «más», y cada serie, un número.
final class AccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaTarjetaDelEntrenoSeEntiendeConVoiceOver() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].appears(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["finish-workout"].appears(timeout: 10))
        app.buttons["card-press_banca"].firstMatch.tap()

        XCTAssertEqual(app.buttons["weight-plus"].firstMatch.label, "Subir peso")
        XCTAssertEqual(app.buttons["weight-minus"].firstMatch.label, "Bajar peso")
        XCTAssertEqual(app.buttons["target-reps-plus"].firstMatch.label, "Subir repeticiones objetivo")
        let weight = app.textFields["weight-field"].firstMatch
        XCTAssertEqual(weight.label, "Peso")
        XCTAssertTrue((weight.value as? String)?.contains("kg") == true)

        let series = app.descendants(matching: .any)["series-0"].firstMatch
        XCTAssertTrue(series.appears(timeout: 5))
        XCTAssertEqual(series.label, "Serie 1")
        let value = series.value as? String ?? ""
        XCTAssertTrue(value.contains("repeticiones") || value.contains("repetición") || value == "Sin completar", value)
    }
}
