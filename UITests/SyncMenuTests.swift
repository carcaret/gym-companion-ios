import XCTest

/// El indicador de la sincronización es un menú de iOS: dice el estado y ofrece lo que toca. Con
/// `-demo` no hay GitHub, así que ofrece configurarlo. (Que el aviso de abajo es un elemento de
/// accesibilidad con su texto lo comprueba `HistoryTests.testTirarHaciaAbajoSincroniza`.)
final class SyncMenuTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElMenuDelIndicadorLlevaAAjustes() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        let indicator = app.buttons["sync-indicator"].firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 20))
        XCTAssertEqual(indicator.label, "GitHub no configurado")
        indicator.tap()
        let configure = app.buttons["Configurar GitHub"].firstMatch
        XCTAssertTrue(configure.waitForExistence(timeout: 10))
        configure.tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].isSelected)
    }
}
