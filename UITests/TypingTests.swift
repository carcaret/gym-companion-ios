import XCTest

/// Lo que solo se ve en iOS: un botón no quita el foco del campo que se está editando, así que lo
/// tecleado tiene que aplicarse antes de la acción (en la web el campo se aplicaba al perder el
/// foco, antes del toque).
final class TypingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Teclear el peso y, con el teclado aún abierto, finalizar: el entreno guarda lo tecleado.
    @MainActor
    func testFinalizarConElTecladoAbierto() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["finish-workout"].waitForExistence(timeout: 10))
        app.buttons["card-press_banca"].firstMatch.tap()

        let weight = app.textFields["Peso (kg)"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        // Al final del texto, para que los borrados se lleven el valor entero.
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "61")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "El teclado tiene que seguir abierto")

        app.buttons["finish-workout"].tap()
        XCTAssertTrue(app.buttons["back-to-routines"].waitForExistence(timeout: 10))
        let typed = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '61 kg'")).firstMatch
        XCTAssertTrue(typed.waitForExistence(timeout: 5), "El entreno terminado no tiene el peso tecleado")
    }
}
