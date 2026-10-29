import XCTest

/// El indicador de la sincronización es un menú de iOS: dice el estado y ofrece lo que toca. Con
/// `-demo` no hay GitHub, así que ofrece configurarlo. (Que el aviso de abajo es un elemento de
/// accesibilidad con su texto lo comprueba `HistoryTests.testTirarHaciaAbajoSincroniza`.)
final class SyncMenuTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Los ajustes no son una pestaña: son una hoja que abre el indicador y se cierra con su botón
    /// (decisión del usuario, 2026-10-26).
    @MainActor
    func testElMenuDelIndicadorAbreLosAjustes() {
        let app = XCUIApplication.launchDemo()
        XCTAssertTrue(app.navigationBars["Rutinas"].appears(timeout: 20))
        XCTAssertFalse(app.tabBars.buttons["Ajustes"].exists, "Ajustes ya no es una pestaña")
        XCTAssertEqual(app.buttons["sync-indicator"].firstMatch.label, "GitHub no configurado")

        app.openSyncSettings()
        XCTAssertTrue(app.textFields["settings-repository"].exists)
        app.buttons["settings-close"].tap()
        XCTAssertTrue(app.navigationBars["Sincronización"].waitForNonExistence(timeout: 5), "La hoja sigue abierta")
        XCTAssertTrue(app.navigationBars["Rutinas"].exists, "Al cerrar se vuelve a donde se estaba")
    }
}
