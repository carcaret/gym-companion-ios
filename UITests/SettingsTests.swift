import XCTest

/// Los ajustes de sincronización como un formulario de iOS: la tecla de retorno pasa al campo siguiente y, en el último,
/// cierra el teclado.
final class SettingsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testRetornoPasaAlCampoSiguiente() {
        let app = XCUIApplication.launchDemo()
        app.openSyncSettings()
        let repository = app.textFields["settings-repository"]
        XCTAssertTrue(repository.appears(timeout: 10))

        repository.tap()
        // En el orden en que se ven: repositorio y token arriba; rama y ruta en «Avanzado».
        repository.typeText("usuario/repo\n")
        XCTAssertTrue(hasFocus(app.secureTextFields["settings-token"]), "Retorno en Repositorio pasa al token")
        app.secureTextFields["settings-token"].typeText("\n")
        XCTAssertTrue(hasFocus(app.textFields["settings-branch"]), "Retorno en el token pasa a Rama")
        app.textFields["settings-branch"].typeText("\n")
        XCTAssertTrue(hasFocus(app.textFields["settings-path"]), "Retorno en Rama pasa a Ruta")
        app.textFields["settings-path"].typeText("\n")

        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        wait(for: [closed], timeout: 5)
    }

    @MainActor
    private func hasFocus(_ field: XCUIElement) -> Bool {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        return XCTWaiter().wait(for: [focused], timeout: 5) == .completed
    }
}
