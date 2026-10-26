import XCTest

/// El teclado se cierra al tocar fuera de un campo y, en Ajustes (un `Form`), al desplazar. Con él
/// abierto la barra de pestañas queda tapada (visto en el iPhone en Ajustes).
final class KeyboardTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Ajustes es un `Form`: como en los formularios de iOS, el teclado se cierra al desplazar (o
    /// con la tecla de retorno, `SettingsTests`), no al tocar una fila, donde el reconocedor de la
    /// ventana no actúa (decisión del usuario, 2026-10-26). Y la barra de pestañas vuelve a responder.
    @MainActor
    func testDesplazarCierraElTecladoEnAjustes() {
        let app = openSettingsWithKeyboard()
        // Desde la cabecera de la sección (no desde un campo) hasta abajo, por encima del teclado:
        // con `.interactively` el teclado sigue al dedo y se cierra.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado sigue abierto")
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.navigationBars["Rutinas"].waitForExistence(timeout: 5))
    }

    /// También en una pantalla que es una lista (elegir ejercicio en Gráficas): tocar fuera del
    /// buscador lo cierra.
    @MainActor
    func testTocarFueraEnUnaLista() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Gráficas"].tap()
        let exercise = app.buttons["chart-exercise"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 10))
        exercise.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No se abrió el teclado")
        // La cabecera de la sección, la escriba iOS en mayúsculas o no.
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "En rutinas")).firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado sigue abierto")
    }

    @MainActor
    private func openSettingsWithKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Ajustes"].tap()
        let repository = app.textFields["settings-repository"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10))
        repository.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No se abrió el teclado")
        return app
    }
}
