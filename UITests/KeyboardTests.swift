import XCTest

/// El teclado se cierra al tocar fuera de un campo. Con él abierto la barra de pestañas queda
/// tapada (visto en el iPhone en Ajustes).
final class KeyboardTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Tocar fuera de un campo cierra el teclado y la barra de pestañas vuelve a responder.
    @MainActor
    func testTocarFueraCierraElTeclado() {
        let app = openSettingsWithKeyboard()
        app.staticTexts["Estado"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado sigue abierto")
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.navigationBars["Rutinas"].waitForExistence(timeout: 5))
    }

    /// También en una pantalla que es una lista (Gráficas): tocar fuera del buscador lo cierra.
    @MainActor
    func testTocarFueraEnUnaLista() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Gráficas"].tap()
        let search = app.textFields["chart-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No se abrió el teclado")
        app.staticTexts["Desde"].tap()
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
