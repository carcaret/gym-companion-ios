import XCTest

/// Recorre las pantallas principales y guarda una captura de cada una en el resultado de los
/// tests; el CI las publica como artefacto "capturas" (ver CLAUDE.md).
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Cada pestaña se abre y enseña su título.
    @MainActor
    func testPestanas() {
        let app = XCUIApplication()
        app.launch()
        let tabs = [("Rutinas", "01-rutinas"), ("Historial", "02-historial"), ("Progreso", "03-progreso"),
                    ("Gráficas", "04-graficas"), ("Ajustes", "05-ajustes")]
        for (title, name) in tabs {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "No se abrió \(title)")
            capture(app, name)
        }
        XCTAssertTrue(app.buttons["sync-indicator"].exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
