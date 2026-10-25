import XCTest

/// El teclado se cierra: al tocar fuera de un campo y con "OK" encima del teclado. Con él abierto
/// la barra de pestañas queda tapada (visto en el iPhone en Ajustes).
final class KeyboardTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Tocar fuera de un campo cierra el teclado y la barra de pestañas vuelve a responder.
    @MainActor
    func testTocarFueraCierraElTeclado() {
        let app = openSettingsWithKeyboard()
        app.staticTexts["Estado"].tap()
        let closed = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        // DIAGNÓSTICO TEMPORAL: qué ha visto el reconocedor.
        let trace = app.descendants(matching: .any)["keyboard-debug"].value as? String ?? "sin rastro"
        XCTAssertTrue(closed, "El teclado sigue abierto. Rastro: \(trace)")
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.navigationBars["Rutinas"].waitForExistence(timeout: 5))
    }

    /// "OK" encima del teclado lo cierra.
    @MainActor
    func testOKCierraElTeclado() {
        let app = openSettingsWithKeyboard()
        app.buttons["OK"].firstMatch.tap()
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
