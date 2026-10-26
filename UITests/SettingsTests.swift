import XCTest

/// Los ajustes de sincronización como un formulario de iOS: la tecla de retorno pasa al campo siguiente y, en el último,
/// cierra el teclado.
final class SettingsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testRetornoPasaAlCampoSiguiente() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.openSyncSettings()
        let repository = app.textFields["settings-repository"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10))

        repository.tap()
        repository.typeText("usuario/repo\n")
        XCTAssertTrue(hasFocus(app.textFields["settings-branch"]), "Retorno en Repositorio pasa a Rama")
        app.textFields["settings-branch"].typeText("\n")
        XCTAssertTrue(hasFocus(app.textFields["settings-path"]), "Retorno en Rama pasa a Ruta")
        app.textFields["settings-path"].typeText("\n")
        XCTAssertTrue(hasFocus(app.secureTextFields["settings-token"]), "Retorno en Ruta pasa al token")
        app.secureTextFields["settings-token"].typeText("\n")

        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        wait(for: [closed], timeout: 5)
    }

    @MainActor
    private func hasFocus(_ field: XCUIElement) -> Bool {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        return XCTWaiter().wait(for: [focused], timeout: 5) == .completed
    }
}
