import XCTest

/// Si los datos del iPhone no se pueden leer, la app lo dice en vez de salir vacía (2026-10-27).
final class DataErrorTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDatosIlegiblesLoDice() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-datos-ilegibles"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No se pudieron leer los datos"].appears(timeout: 20), app.debugDescription)
        let retry = app.buttons["data-retry"]
        XCTAssertTrue(retry.exists)
        // Con `-demo` no hay GitHub: no se ofrece descargar.
        XCTAssertFalse(app.buttons["data-download"].exists)
        // Reintentar con el fichero aún estropeado sigue diciéndolo.
        retry.tap()
        XCTAssertTrue(app.staticTexts["No se pudieron leer los datos"].appears(timeout: 10))
    }
}
