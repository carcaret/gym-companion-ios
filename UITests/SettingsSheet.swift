import XCTest

extension XCUIApplication {
    /// Abre los ajustes de sincronización como lo haría el usuario: el menú del indicador y, con
    /// `-demo` (sin GitHub), «Configurar GitHub».
    @MainActor
    func openSyncSettings() {
        let indicator = buttons["sync-indicator"].firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 20))
        indicator.tap()
        let configure = buttons["Configurar GitHub"].firstMatch
        XCTAssertTrue(configure.waitForExistence(timeout: 10))
        configure.tap()
        XCTAssertTrue(navigationBars["Sincronización"].waitForExistence(timeout: 10), "No se abrió la hoja de los ajustes")
    }
}
