import XCTest

/// PRUEBA (no fusionar): capturas de varias pantallas con el tamaño de texto normal de iOS, el
/// máximo sin accesibilidad y uno de los de accesibilidad.
final class DynamicTypeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testNormal() { recorrer("UICTContentSizeCategoryL", "texto-1-normal") }
    @MainActor func testMaximo() { recorrer("UICTContentSizeCategoryXXXL", "texto-2-maximo") }
    @MainActor func testAccesibilidad() { recorrer("UICTContentSizeCategoryAccessibilityL", "texto-3-accesibilidad") }

    @MainActor
    private func recorrer(_ category: String, _ prefix: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 10))
        capture(app, "\(prefix)-a-rutinas")
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["finish-workout"].waitForExistence(timeout: 10))
        app.buttons["card-press_banca"].firstMatch.tap()
        capture(app, "\(prefix)-b-entreno")
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        capture(app, "\(prefix)-c-historial")
        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.buttons["stats-exercises"].waitForExistence(timeout: 10))
        app.buttons["stats-exercises"].tap()
        capture(app, "\(prefix)-d-progreso")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
