import XCTest

/// PRUEBA DE DISEÑO (rama `diseno-ios`): las mismas pantallas con cada estilo de `DesignStyle`,
/// para compararlas en el artefacto «capturas» (`80-<estilo>-…`). Desaparece al elegir uno.
final class DesignPreviewTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testPwa() { recorrer("pwa") }
    @MainActor func testCristal() { recorrer("cristal") }
    @MainActor func testNativo() { recorrer("nativo") }
    @MainActor func testMixto() { recorrer("mixto") }

    @MainActor
    private func recorrer(_ style: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-estilo", style]
        app.launch()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 20))
        capture(app, style, "1-rutinas")

        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch.waitForExistence(timeout: 10))
        capture(app, style, "2-historial")

        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.buttons["stats-exercises"].waitForExistence(timeout: 10))
        app.buttons["stats-exercises"].tap()
        capture(app, style, "3-progreso")

        app.tabBars.buttons["Rutinas"].tap()
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        capture(app, style, "4-vista-previa")

        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["finish-workout"].waitForExistence(timeout: 10))
        capture(app, style, "5-entreno")

        app.buttons["card-press_banca"].firstMatch.tap()
        capture(app, style, "6-tarjeta")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ style: String, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "80-\(style)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
